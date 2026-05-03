package service

import (
	"context"
	"errors"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

var (
	ErrInvalidBankTarget        = errors.New("target is not a bank")
	ErrBankTooFar               = errors.New("player must be next to the bank")
	ErrInvalidBankDeposit       = errors.New("deposit quantity must be positive")
	ErrInventoryItemUnavailable = errors.New("item is not available in inventory")
)

type InventoryService struct {
	inventory store.InventoryStore
	bank      store.BankStore
	players   store.PlayerStore
	entities  store.EntityStore
	actions   *ActionService
	now       func() time.Time
}

func NewInventoryService(inventory store.InventoryStore, bank store.BankStore, players store.PlayerStore, entities store.EntityStore, actions *ActionService) *InventoryService {
	return &InventoryService{
		inventory: inventory,
		bank:      bank,
		players:   players,
		entities:  entities,
		actions:   actions,
		now:       func() time.Time { return time.Now().UTC() },
	}
}

func (s *InventoryService) List(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error) {
	return s.inventory.ListInventory(ctx, userID)
}

func (s *InventoryService) ListBank(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error) {
	return s.bank.ListBank(ctx, userID)
}

func (s *InventoryService) Deposit(ctx context.Context, userID uuid.UUID, entityID uuid.UUID, itemKey string, quantity int64) (int64, error) {
	if quantity <= 0 || itemKey == "" {
		return 0, ErrInvalidBankDeposit
	}

	player, err := s.players.GetPlayer(ctx, userID)
	if err != nil {
		return 0, err
	}
	if movement := player.Movement; movement != nil {
		now := s.now()
		if now.Before(movement.ArrivesAt) {
			return 0, ErrPlayerIsMoving
		}
		player.X = movement.TargetX
		player.Y = movement.TargetY
		player.Movement = nil
		if _, err := s.players.SavePlayer(ctx, player); err != nil {
			return 0, err
		}
	}

	entities, err := ensureResourceNodes(ctx, s.entities, userID, s.now())
	if err != nil {
		return 0, err
	}
	var bankEntity *domain.Entity
	for i := range entities {
		if entities[i].ID == entityID {
			bankEntity = &entities[i]
			break
		}
	}
	if bankEntity == nil || bankEntity.Type != bankEntityType {
		return 0, ErrInvalidBankTarget
	}
	if !isAdjacentToEntity(domain.Point{X: player.X, Y: player.Y}, *bankEntity) {
		return 0, ErrBankTooFar
	}

	moved, err := s.bank.DepositInventoryItem(ctx, userID, itemKey, quantity)
	if err != nil {
		return 0, err
	}
	if moved <= 0 {
		return 0, ErrInventoryItemUnavailable
	}
	return moved, nil
}
