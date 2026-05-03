package service

import (
	"context"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

type EventService struct {
	events store.EventStore
}

func NewEventService(events store.EventStore) *EventService {
	return &EventService{events: events}
}

func (s *EventService) List(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerEvent, error) {
	if s == nil || s.events == nil {
		return nil, nil
	}
	return s.events.ListEvents(ctx, userID, afterID, limit)
}
