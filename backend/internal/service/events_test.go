package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestEventServiceAckInboxMarksItemsRead(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.May, 3, 18, 0, 0, 0, time.UTC)
	inbox := &memoryEventInbox{
		items: []domain.PlayerInboxItem{
			{
				ID:          1,
				UserID:      userID,
				EventID:     10,
				EventType:   "action.completed",
				Status:      "unread",
				DeliveredAt: now.Add(-time.Minute),
				CreatedAt:   now.Add(-time.Minute),
			},
		},
	}
	service := NewEventService(inbox)
	service.now = func() time.Time { return now }

	items, err := service.AckInbox(context.Background(), userID, []int64{1})
	if err != nil {
		t.Fatalf("AckInbox returned error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 acked item, got %d", len(items))
	}
	if items[0].Status != "read" {
		t.Fatalf("expected acked item status read, got %q", items[0].Status)
	}
	if items[0].ReadAt == nil || !items[0].ReadAt.Equal(now) {
		t.Fatalf("expected read_at %s, got %#v", now, items[0].ReadAt)
	}
}
