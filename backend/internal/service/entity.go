package service

import (
	"context"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

type EntityService struct {
	store store.EntityStore
}

func NewEntityService(store store.EntityStore) *EntityService {
	return &EntityService{store: store}
}

func (s *EntityService) List(ctx context.Context, userID uuid.UUID) ([]domain.Entity, error) {
	return ensureResourceNodes(ctx, s.store, userID, time.Now().UTC())
}
