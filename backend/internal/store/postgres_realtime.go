package store

import (
	"context"
	"encoding/json"
	"sort"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

const RealtimeNotifyChannel = "player_realtime"

type PostgresRealtimeStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresRealtimeStore) PublishRealtime(ctx context.Context, notification RealtimeNotification) error {
	return publishRealtime(ctx, s.pool, notification)
}

type PostgresRealtimeTxStore struct {
	tx pgx.Tx
}

func (s *PostgresRealtimeTxStore) PublishRealtime(ctx context.Context, notification RealtimeNotification) error {
	return publishRealtime(ctx, s.tx, notification)
}

type pgxExec interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

func publishRealtime(ctx context.Context, db pgxExec, notification RealtimeNotification) error {
	if notification.UserID == uuid.Nil {
		return nil
	}

	topics := canonicalRealtimeTopics(notification.Topics)
	if len(topics) == 0 {
		return nil
	}
	notification.Topics = topics

	payload, err := json.Marshal(struct {
		UserID string   `json:"user_id"`
		Topics []string `json:"topics"`
	}{
		UserID: notification.UserID.String(),
		Topics: notification.Topics,
	})
	if err != nil {
		return err
	}

	_, err = db.Exec(ctx, `select pg_notify($1, $2)`, RealtimeNotifyChannel, string(payload))
	return err
}

func canonicalRealtimeTopics(topics []string) []string {
	if len(topics) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(topics))
	result := make([]string, 0, len(topics))
	for _, topic := range topics {
		topic = strings.TrimSpace(topic)
		if topic == "" {
			continue
		}
		if _, ok := seen[topic]; ok {
			continue
		}
		seen[topic] = struct{}{}
		result = append(result, topic)
	}
	sort.Strings(result)
	return result
}
