package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

func TestEventDispatcherProcessPendingMovesOutboxToInbox(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.May, 3, 12, 0, 0, 0, time.UTC)
	events := &memoryEvents{
		events: []domain.PlayerEvent{
			{
				ID:            1,
				UserID:        userID,
				AggregateType: "action",
				EventType:     "action.completed",
				Payload:       map[string]any{"resource_key": "oak_tree"},
				CreatedAt:     now.Add(-time.Second),
			},
		},
	}
	outbox := &memoryEventOutbox{
		deliveries: []domain.PlayerEventDelivery{
			{
				ID:          1,
				EventID:     1,
				UserID:      userID,
				Destination: eventDeliveryDestinationInbox,
				Status:      eventDeliveryStatusPending,
				AvailableAt: now.Add(-time.Second),
				CreatedAt:   now.Add(-time.Second),
			},
		},
	}
	inbox := &memoryEventInbox{}
	dispatcher := NewEventDispatcher(&memoryTransactor{
		stores: store.Stores{
			Events:      events,
			EventOutbox: outbox,
			EventInbox:  inbox,
		},
	})
	dispatcher.now = func() time.Time { return now }

	processed, err := dispatcher.ProcessPending(context.Background(), 4)
	if err != nil {
		t.Fatalf("ProcessPending returned error: %v", err)
	}
	if processed != 1 {
		t.Fatalf("expected 1 processed delivery, got %d", processed)
	}
	if len(inbox.items) != 1 {
		t.Fatalf("expected 1 inbox item, got %d", len(inbox.items))
	}
	if inbox.items[0].EventID != 1 {
		t.Fatalf("expected inbox event_id 1, got %d", inbox.items[0].EventID)
	}
	if got := outbox.deliveries[0].Status; got != "delivered" {
		t.Fatalf("expected delivery status delivered, got %q", got)
	}
}

type memoryTransactor struct {
	stores store.Stores
}

func (m *memoryTransactor) WithinTx(_ context.Context, fn func(store.Stores) error) error {
	return fn(m.stores)
}

type memoryEventOutbox struct {
	deliveries []domain.PlayerEventDelivery
}

func (m *memoryEventOutbox) EnqueueDeliveries(_ context.Context, deliveries []domain.PlayerEventDelivery) ([]domain.PlayerEventDelivery, error) {
	for _, delivery := range deliveries {
		delivery.ID = int64(len(m.deliveries) + 1)
		m.deliveries = append(m.deliveries, delivery)
	}
	return deliveries, nil
}

func (m *memoryEventOutbox) ClaimNextPendingDelivery(_ context.Context, destination string, now time.Time) (*domain.PlayerEventDelivery, error) {
	for i := range m.deliveries {
		delivery := &m.deliveries[i]
		if delivery.Destination != destination || delivery.Status != eventDeliveryStatusPending || delivery.AvailableAt.After(now) {
			continue
		}
		copy := *delivery
		return &copy, nil
	}
	return nil, nil
}

func (m *memoryEventOutbox) MarkDeliveryDelivered(_ context.Context, deliveryID int64, deliveredAt time.Time) error {
	for i := range m.deliveries {
		if m.deliveries[i].ID != deliveryID {
			continue
		}
		m.deliveries[i].Status = "delivered"
		m.deliveries[i].DeliveredAt = &deliveredAt
		return nil
	}
	return nil
}

type memoryEventInbox struct {
	items []domain.PlayerInboxItem
}

func (m *memoryEventInbox) ListInbox(_ context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerInboxItem, error) {
	result := []domain.PlayerInboxItem{}
	for _, item := range m.items {
		if item.UserID != userID || item.ID <= afterID {
			continue
		}
		result = append(result, item)
		if limit > 0 && len(result) >= limit {
			break
		}
	}
	return result, nil
}

func (m *memoryEventInbox) AppendInboxItems(_ context.Context, items []domain.PlayerInboxItem) ([]domain.PlayerInboxItem, error) {
	appended := make([]domain.PlayerInboxItem, 0, len(items))
	for _, item := range items {
		item.ID = int64(len(m.items) + 1)
		m.items = append(m.items, item)
		appended = append(appended, item)
	}
	return appended, nil
}

func (m *memoryEventInbox) MarkInboxItemsRead(_ context.Context, userID uuid.UUID, ids []int64, readAt time.Time) ([]domain.PlayerInboxItem, error) {
	updated := []domain.PlayerInboxItem{}
	allowed := make(map[int64]struct{}, len(ids))
	for _, id := range ids {
		allowed[id] = struct{}{}
	}
	for i := range m.items {
		item := &m.items[i]
		if item.UserID != userID {
			continue
		}
		if _, ok := allowed[item.ID]; !ok {
			continue
		}
		item.Status = "read"
		item.ReadAt = &readAt
		updated = append(updated, *item)
	}
	return updated, nil
}
