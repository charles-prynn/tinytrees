package service

import (
	"context"
	"errors"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

var ErrInvalidStateVersion = errors.New("state version must be positive")

type StateService struct {
	store store.StateStore
}

func NewStateService(store store.StateStore) *StateService {
	return &StateService{store: store}
}

func (s *StateService) Load(ctx context.Context, userID uuid.UUID) (domain.StateSnapshot, error) {
	return s.store.GetSnapshot(ctx, userID)
}

func (s *StateService) Sync(ctx context.Context, snapshot domain.StateSnapshot) (domain.StateSnapshot, error) {
	if snapshot.Version <= 0 {
		return domain.StateSnapshot{}, ErrInvalidStateVersion
	}
	if snapshot.Metadata == nil {
		snapshot.Metadata = map[string]any{}
	}
	return s.store.SaveSnapshot(ctx, snapshot)
}
