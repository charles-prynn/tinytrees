package service

import (
	"context"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

type InventoryService struct {
	inventory store.InventoryStore
	actions   *ActionService
}

func NewInventoryService(inventory store.InventoryStore, actions *ActionService) *InventoryService {
	return &InventoryService{inventory: inventory, actions: actions}
}

func (s *InventoryService) List(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error) {
	if s.actions != nil {
		if _, err := s.actions.Resolve(ctx, userID); err != nil {
			return nil, err
		}
	}
	return s.inventory.ListInventory(ctx, userID)
}
