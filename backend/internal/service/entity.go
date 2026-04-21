package service

import (
	"context"

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
	entities, err := s.store.ListEntities(ctx, userID)
	if err != nil {
		return nil, err
	}
	if len(entities) > 0 {
		return entities, nil
	}

	entity, err := s.store.CreateEntity(ctx, defaultResourceEntity(userID))
	if err != nil {
		return nil, err
	}
	return []domain.Entity{entity}, nil
}

func defaultResourceEntity(userID uuid.UUID) domain.Entity {
	return domain.Entity{
		ID:          uuid.New(),
		UserID:      userID,
		Name:        "Tree",
		Type:        "resource",
		ResourceKey: "autumn_tree",
		X:           32,
		Y:           16,
		Width:       1,
		Height:      1,
		SpriteGID:   5,
		State:       "idle",
		Metadata:    map[string]any{},
	}
}
