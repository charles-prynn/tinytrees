package store

import (
	"context"
	"encoding/json"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresEventOutboxStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresEventOutboxStore) EnqueueDeliveries(ctx context.Context, deliveries []domain.PlayerEventDelivery) ([]domain.PlayerEventDelivery, error) {
	return enqueueDeliveries(ctx, s.pool, deliveries)
}

func (s *PostgresEventOutboxStore) ClaimNextPendingDelivery(ctx context.Context, destination string, now time.Time) (*domain.PlayerEventDelivery, error) {
	return claimNextPendingDelivery(ctx, s.pool, destination, now)
}

func (s *PostgresEventOutboxStore) MarkDeliveryDelivered(ctx context.Context, deliveryID int64, deliveredAt time.Time) error {
	return markDeliveryDelivered(ctx, s.pool, deliveryID, deliveredAt)
}

type PostgresEventOutboxTxStore struct {
	tx pgx.Tx
}

func (s *PostgresEventOutboxTxStore) EnqueueDeliveries(ctx context.Context, deliveries []domain.PlayerEventDelivery) ([]domain.PlayerEventDelivery, error) {
	return enqueueDeliveries(ctx, s.tx, deliveries)
}

func (s *PostgresEventOutboxTxStore) ClaimNextPendingDelivery(ctx context.Context, destination string, now time.Time) (*domain.PlayerEventDelivery, error) {
	return claimNextPendingDelivery(ctx, s.tx, destination, now)
}

func (s *PostgresEventOutboxTxStore) MarkDeliveryDelivered(ctx context.Context, deliveryID int64, deliveredAt time.Time) error {
	return markDeliveryDelivered(ctx, s.tx, deliveryID, deliveredAt)
}

type PostgresEventInboxStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresEventInboxStore) ListInbox(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerInboxItem, error) {
	return listInbox(ctx, s.pool, userID, afterID, limit)
}

func (s *PostgresEventInboxStore) AppendInboxItems(ctx context.Context, items []domain.PlayerInboxItem) ([]domain.PlayerInboxItem, error) {
	return appendInboxItems(ctx, s.pool, items)
}

func (s *PostgresEventInboxStore) MarkInboxItemsRead(ctx context.Context, userID uuid.UUID, ids []int64, readAt time.Time) ([]domain.PlayerInboxItem, error) {
	return markInboxItemsRead(ctx, s.pool, userID, ids, readAt)
}

type PostgresEventInboxTxStore struct {
	tx pgx.Tx
}

func (s *PostgresEventInboxTxStore) ListInbox(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerInboxItem, error) {
	return listInbox(ctx, s.tx, userID, afterID, limit)
}

func (s *PostgresEventInboxTxStore) AppendInboxItems(ctx context.Context, items []domain.PlayerInboxItem) ([]domain.PlayerInboxItem, error) {
	return appendInboxItems(ctx, s.tx, items)
}

func (s *PostgresEventInboxTxStore) MarkInboxItemsRead(ctx context.Context, userID uuid.UUID, ids []int64, readAt time.Time) ([]domain.PlayerInboxItem, error) {
	return markInboxItemsRead(ctx, s.tx, userID, ids, readAt)
}

func enqueueDeliveries(ctx context.Context, db pgxQuery, deliveries []domain.PlayerEventDelivery) ([]domain.PlayerEventDelivery, error) {
	if len(deliveries) == 0 {
		return nil, nil
	}

	enqueued := make([]domain.PlayerEventDelivery, 0, len(deliveries))
	for _, delivery := range deliveries {
		if delivery.Status == "" {
			delivery.Status = "pending"
		}
		if delivery.AvailableAt.IsZero() {
			delivery.AvailableAt = time.Now().UTC()
		}
		err := db.QueryRow(ctx, `
			insert into player_event_outbox (event_id, user_id, destination, status, available_at)
			values ($1, $2, $3, $4, $5)
			returning id, created_at
		`, delivery.EventID, delivery.UserID, delivery.Destination, delivery.Status, delivery.AvailableAt).Scan(&delivery.ID, &delivery.CreatedAt)
		if err != nil {
			return nil, err
		}
		enqueued = append(enqueued, delivery)
	}
	return enqueued, nil
}

func claimNextPendingDelivery(ctx context.Context, db pgxQuery, destination string, now time.Time) (*domain.PlayerEventDelivery, error) {
	row := db.QueryRow(ctx, `
		with next_delivery as (
			select id
			from player_event_outbox
			where status = 'pending'
			  and destination = $1
			  and available_at <= $2
			order by available_at, id
			for update skip locked
			limit 1
		)
		select id, event_id, user_id, destination, status, available_at, delivered_at, created_at
		from player_event_outbox
		where id = (select id from next_delivery)
	`, destination, now)
	return scanDelivery(row)
}

func markDeliveryDelivered(ctx context.Context, db pgxQuery, deliveryID int64, deliveredAt time.Time) error {
	var id int64
	err := db.QueryRow(ctx, `
		update player_event_outbox
		set status = 'delivered',
			delivered_at = $2
		where id = $1
		returning id
	`, deliveryID, deliveredAt).Scan(&id)
	return err
}

func listInbox(ctx context.Context, db pgxQuery, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerInboxItem, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := db.Query(ctx, `
		select inbox.id,
		       inbox.user_id,
		       inbox.event_id,
		       events.aggregate_type,
		       events.aggregate_id,
		       events.event_type,
		       inbox.status,
		       events.payload,
		       inbox.delivered_at,
		       inbox.read_at,
		       inbox.created_at
		from player_event_inbox inbox
		join player_events events on events.id = inbox.event_id
		where inbox.user_id = $1 and inbox.id > $2
		order by inbox.id asc
		limit $3
	`, userID, afterID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.PlayerInboxItem{}
	for rows.Next() {
		item, err := scanInboxItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func appendInboxItems(ctx context.Context, db pgxQuery, items []domain.PlayerInboxItem) ([]domain.PlayerInboxItem, error) {
	if len(items) == 0 {
		return nil, nil
	}

	appended := make([]domain.PlayerInboxItem, 0, len(items))
	for _, item := range items {
		if item.Status == "" {
			item.Status = "unread"
		}
		if item.DeliveredAt.IsZero() {
			item.DeliveredAt = time.Now().UTC()
		}
		err := db.QueryRow(ctx, `
			insert into player_event_inbox (user_id, event_id, status, delivered_at)
			values ($1, $2, $3, $4)
			returning id, created_at
		`, item.UserID, item.EventID, item.Status, item.DeliveredAt).Scan(&item.ID, &item.CreatedAt)
		if err != nil {
			return nil, err
		}
		appended = append(appended, item)
	}
	return appended, nil
}

func markInboxItemsRead(ctx context.Context, db pgxQuery, userID uuid.UUID, ids []int64, readAt time.Time) ([]domain.PlayerInboxItem, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	rows, err := db.Query(ctx, `
		with updated as (
			update player_event_inbox
			set status = 'read',
				read_at = coalesce(read_at, $3)
			where user_id = $1
			  and id = any($2)
			returning id
		)
		select inbox.id,
		       inbox.user_id,
		       inbox.event_id,
		       events.aggregate_type,
		       events.aggregate_id,
		       events.event_type,
		       inbox.status,
		       events.payload,
		       inbox.delivered_at,
		       inbox.read_at,
		       inbox.created_at
		from player_event_inbox inbox
		join player_events events on events.id = inbox.event_id
		where inbox.id in (select id from updated)
		order by inbox.id asc
	`, userID, ids, readAt)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.PlayerInboxItem{}
	for rows.Next() {
		item, err := scanInboxItem(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func scanDelivery(row interface {
	Scan(...any) error
}) (*domain.PlayerEventDelivery, error) {
	var delivery domain.PlayerEventDelivery
	err := row.Scan(
		&delivery.ID,
		&delivery.EventID,
		&delivery.UserID,
		&delivery.Destination,
		&delivery.Status,
		&delivery.AvailableAt,
		&delivery.DeliveredAt,
		&delivery.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &delivery, nil
}

func scanInboxItem(row interface {
	Scan(...any) error
}) (domain.PlayerInboxItem, error) {
	var item domain.PlayerInboxItem
	var aggregateID *uuid.UUID
	var payload []byte
	err := row.Scan(
		&item.ID,
		&item.UserID,
		&item.EventID,
		&item.AggregateType,
		&aggregateID,
		&item.EventType,
		&item.Status,
		&payload,
		&item.DeliveredAt,
		&item.ReadAt,
		&item.CreatedAt,
	)
	if err != nil {
		return domain.PlayerInboxItem{}, err
	}
	item.AggregateID = aggregateID
	if err := json.Unmarshal(payload, &item.Payload); err != nil {
		item.Payload = map[string]any{}
	}
	return item, nil
}
