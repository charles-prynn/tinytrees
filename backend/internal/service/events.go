package service

import (
	"context"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

type EventService struct {
	inbox    store.EventInboxStore
	realtime store.RealtimeStore
	now      func() time.Time
}

func NewEventService(inbox store.EventInboxStore) *EventService {
	return &EventService{
		inbox: inbox,
		now:   func() time.Time { return time.Now().UTC() },
	}
}

func (s *EventService) SetRealtimeStore(realtime store.RealtimeStore) {
	s.realtime = realtime
}

func (s *EventService) ListInbox(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerInboxItem, error) {
	if s == nil || s.inbox == nil {
		return nil, nil
	}
	return s.inbox.ListInbox(ctx, userID, afterID, limit)
}

func (s *EventService) AckInbox(ctx context.Context, userID uuid.UUID, ids []int64) ([]domain.PlayerInboxItem, error) {
	if s == nil || s.inbox == nil || len(ids) == 0 {
		return nil, nil
	}
	items, err := s.inbox.MarkInboxItemsRead(ctx, userID, ids, s.now())
	if err != nil {
		return nil, err
	}
	if len(items) > 0 {
		notifyRealtimeBestEffort(ctx, s.realtime, userID, realtimeTopicEvents)
	}
	return items, nil
}
