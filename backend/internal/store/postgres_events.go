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

func (s *PostgresEventStore) GetEvent(ctx context.Context, eventID int64) (domain.PlayerEvent, error) {
	return getPlayerEvent(ctx, s.pool, eventID)
}

func (s *PostgresEventStore) AppendEvents(ctx context.Context, events []domain.PlayerEvent) ([]domain.PlayerEvent, error) {
	return appendPlayerEvents(ctx, s.pool, events)
}

type PostgresEventTxStore struct {
	tx pgx.Tx
}

func (s *PostgresEventTxStore) GetEvent(ctx context.Context, eventID int64) (domain.PlayerEvent, error) {
	return getPlayerEvent(ctx, s.tx, eventID)
}

func (s *PostgresEventTxStore) AppendEvents(ctx context.Context, events []domain.PlayerEvent) ([]domain.PlayerEvent, error) {
	return appendPlayerEvents(ctx, s.tx, events)
}

type pgxQuery interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}

func getPlayerEvent(ctx context.Context, db pgxQuery, eventID int64) (domain.PlayerEvent, error) {
	row := db.QueryRow(ctx, `
		select id, user_id, aggregate_type, aggregate_id, event_type, payload, created_at
		from player_events
		where id = $1
	`, eventID)
	return scanPlayerEvent(row)
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
		if err == pgx.ErrNoRows {
			return domain.PlayerEvent{}, err
		}
		return domain.PlayerEvent{}, err
	}
	event.AggregateID = aggregateID
	if err := json.Unmarshal(payload, &event.Payload); err != nil {
		event.Payload = map[string]any{}
	}
	return event, nil
}
