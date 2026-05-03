package store

import (
	"context"
	"encoding/json"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresEventStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresEventStore) ListEvents(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerEvent, error) {
	return listPlayerEvents(ctx, s.pool, userID, afterID, limit)
}

func (s *PostgresEventStore) AppendEvents(ctx context.Context, events []domain.PlayerEvent) ([]domain.PlayerEvent, error) {
	return appendPlayerEvents(ctx, s.pool, events)
}

type PostgresEventTxStore struct {
	tx pgx.Tx
}

func (s *PostgresEventTxStore) ListEvents(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerEvent, error) {
	return listPlayerEvents(ctx, s.tx, userID, afterID, limit)
}

func (s *PostgresEventTxStore) AppendEvents(ctx context.Context, events []domain.PlayerEvent) ([]domain.PlayerEvent, error) {
	return appendPlayerEvents(ctx, s.tx, events)
}

type pgxQuery interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}

func listPlayerEvents(ctx context.Context, db pgxQuery, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerEvent, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := db.Query(ctx, `
		select id, user_id, aggregate_type, aggregate_id, event_type, payload, created_at
		from player_events
		where user_id = $1 and id > $2
		order by id asc
		limit $3
	`, userID, afterID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	events := []domain.PlayerEvent{}
	for rows.Next() {
		event, err := scanPlayerEvent(rows)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	return events, rows.Err()
}

func appendPlayerEvents(ctx context.Context, db pgxQuery, events []domain.PlayerEvent) ([]domain.PlayerEvent, error) {
	if len(events) == 0 {
		return nil, nil
	}

	appended := make([]domain.PlayerEvent, 0, len(events))
	for _, event := range events {
		if event.Payload == nil {
			event.Payload = map[string]any{}
		}
		payload, err := json.Marshal(event.Payload)
		if err != nil {
			return nil, err
		}
		err = db.QueryRow(ctx, `
			insert into player_events (user_id, aggregate_type, aggregate_id, event_type, payload)
			values ($1, $2, $3, $4, $5)
			returning id, created_at
		`, event.UserID, event.AggregateType, event.AggregateID, event.EventType, payload).Scan(&event.ID, &event.CreatedAt)
		if err != nil {
			return nil, err
		}
		appended = append(appended, event)
	}
	return appended, nil
}

func scanPlayerEvent(row interface {
	Scan(...any) error
}) (domain.PlayerEvent, error) {
	var event domain.PlayerEvent
	var aggregateID *uuid.UUID
	var payload []byte
	err := row.Scan(
		&event.ID,
		&event.UserID,
		&event.AggregateType,
		&aggregateID,
		&event.EventType,
		&payload,
		&event.CreatedAt,
	)
	if err != nil {
		return domain.PlayerEvent{}, err
	}
	event.AggregateID = aggregateID
	if err := json.Unmarshal(payload, &event.Payload); err != nil {
		event.Payload = map[string]any{}
	}
	return event, nil
}
