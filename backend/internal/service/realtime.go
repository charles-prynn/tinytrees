package service

import (
	"context"
	"encoding/json"
	"sort"
	"strings"
	"sync"
	"time"

	"starter/backend/internal/store"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const (
	realtimeTopicPlayer    = "player"
	realtimeTopicInventory = "inventory"
	realtimeTopicBank      = "bank"
	realtimeTopicEntities  = "entities"
	realtimeTopicEvents    = "events"
)

const realtimeReconnectDelay = time.Second

type RealtimeBroker struct {
	databaseURL string

	mu          sync.RWMutex
	subscribers map[uuid.UUID]map[*realtimeSubscription]struct{}
}

type realtimeSubscription struct {
	ch chan store.RealtimeNotification
}

func NewRealtimeBroker(databaseURL string) *RealtimeBroker {
	return &RealtimeBroker{
		databaseURL: databaseURL,
		subscribers: make(map[uuid.UUID]map[*realtimeSubscription]struct{}),
	}
}

func (b *RealtimeBroker) Subscribe(userID uuid.UUID) (<-chan store.RealtimeNotification, func()) {
	subscription := &realtimeSubscription{ch: make(chan store.RealtimeNotification, 1)}

	b.mu.Lock()
	if b.subscribers[userID] == nil {
		b.subscribers[userID] = make(map[*realtimeSubscription]struct{})
	}
	b.subscribers[userID][subscription] = struct{}{}
	b.mu.Unlock()

	unsubscribe := func() {
		b.mu.Lock()
		defer b.mu.Unlock()

		subscribers := b.subscribers[userID]
		delete(subscribers, subscription)
		if len(subscribers) == 0 {
			delete(b.subscribers, userID)
		}
	}

	return subscription.ch, unsubscribe
}

func (b *RealtimeBroker) Run(ctx context.Context, log interface {
	Info(string, ...any)
	Error(string, ...any)
}) {
	if b == nil || strings.TrimSpace(b.databaseURL) == "" {
		return
	}

	for ctx.Err() == nil {
		if err := b.runListener(ctx, log); err != nil && ctx.Err() == nil && log != nil {
			log.Error("realtime listener failed", "error", err)
		}
		if ctx.Err() != nil {
			return
		}

		timer := time.NewTimer(realtimeReconnectDelay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
	}
}

func (b *RealtimeBroker) runListener(ctx context.Context, log interface {
	Info(string, ...any)
	Error(string, ...any)
}) error {
	conn, err := pgx.Connect(ctx, b.databaseURL)
	if err != nil {
		return err
	}
	defer conn.Close(context.Background())

	if _, err := conn.Exec(ctx, "listen "+store.RealtimeNotifyChannel); err != nil {
		return err
	}
	if log != nil {
		log.Info("realtime listener connected", "channel", store.RealtimeNotifyChannel)
	}

	for ctx.Err() == nil {
		notification, err := conn.WaitForNotification(ctx)
		if err != nil {
			return err
		}

		parsed, err := parseRealtimeNotification(notification.Payload)
		if err != nil {
			if log != nil {
				log.Error("realtime listener ignored malformed payload", "error", err)
			}
			continue
		}
		b.dispatch(parsed)
	}
	return ctx.Err()
}

func (b *RealtimeBroker) dispatch(notification store.RealtimeNotification) {
	if b == nil || notification.UserID == uuid.Nil {
		return
	}

	notification.Topics = normalizeRealtimeTopics(notification.Topics...)
	if len(notification.Topics) == 0 {
		return
	}

	b.mu.RLock()
	subscribers := b.subscribers[notification.UserID]
	targets := make([]*realtimeSubscription, 0, len(subscribers))
	for subscription := range subscribers {
		targets = append(targets, subscription)
	}
	b.mu.RUnlock()

	for _, subscription := range targets {
		queueRealtimeNotification(subscription.ch, notification)
	}
}

func queueRealtimeNotification(ch chan store.RealtimeNotification, notification store.RealtimeNotification) {
	select {
	case ch <- notification:
		return
	default:
	}

	select {
	case pending := <-ch:
		notification.Topics = normalizeRealtimeTopics(append(pending.Topics, notification.Topics...)...)
	default:
	}

	select {
	case ch <- notification:
	default:
	}
}

func parseRealtimeNotification(payload string) (store.RealtimeNotification, error) {
	var raw struct {
		UserID string   `json:"user_id"`
		Topics []string `json:"topics"`
	}
	if err := json.Unmarshal([]byte(payload), &raw); err != nil {
		return store.RealtimeNotification{}, err
	}

	userID, err := uuid.Parse(strings.TrimSpace(raw.UserID))
	if err != nil {
		return store.RealtimeNotification{}, err
	}

	return store.RealtimeNotification{
		UserID: userID,
		Topics: normalizeRealtimeTopics(raw.Topics...),
	}, nil
}

func notifyRealtime(ctx context.Context, realtime store.RealtimeStore, userID uuid.UUID, topics ...string) error {
	if realtime == nil || userID == uuid.Nil {
		return nil
	}

	topics = normalizeRealtimeTopics(topics...)
	if len(topics) == 0 {
		return nil
	}

	return realtime.PublishRealtime(ctx, store.RealtimeNotification{
		UserID: userID,
		Topics: topics,
	})
}

func notifyRealtimeBestEffort(ctx context.Context, realtime store.RealtimeStore, userID uuid.UUID, topics ...string) {
	_ = notifyRealtime(ctx, realtime, userID, topics...)
}

func notifyRealtimeStores(ctx context.Context, stores store.Stores, userID uuid.UUID, topics ...string) error {
	return notifyRealtime(ctx, stores.Realtime, userID, topics...)
}

func normalizeRealtimeTopics(topics ...string) []string {
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
