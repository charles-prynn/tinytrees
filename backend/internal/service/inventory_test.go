package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestInventoryServiceDepositMovesItemsIntoBank(t *testing.T) {
	userID := uuid.New()
	bankID := uuid.New()
	inventory := &memoryInventory{
		items: map[string]int64{"logs": 120},
	}
	bank := &memoryBank{inventory: inventory}
	service := NewInventoryService(
		inventory,
		bank,
		&memoryPlayerStore{
			player: domain.Player{UserID: userID, X: 17, Y: 8},
		},
		&memoryEntities{
			items: []domain.Entity{
				{
					ID:          bankID,
					UserID:      userID,
					Name:        "Bank",
					Type:        bankEntityType,
					ResourceKey: bankEntityResourceKey,
					X:           18,
					Y:           8,
					Width:       1,
					Height:      1,
					State:       resourceStateIdle,
				},
			},
		},
		nil,
	)
	service.now = func() time.Time { return time.Date(2026, time.May, 3, 12, 0, 0, 0, time.UTC) }

	moved, err := service.Deposit(context.Background(), userID, bankID, "logs", 120)
	if err != nil {
		t.Fatalf("Deposit returned error: %v", err)
	}
	if moved != 120 {
		t.Fatalf("expected 120 moved, got %d", moved)
	}
	if got := inventory.items["logs"]; got != 0 {
		t.Fatalf("expected inventory to be empty, got %d", got)
	}
	if got := bank.items["logs"]; got != 120 {
		t.Fatalf("expected bank to contain 120 logs, got %d", got)
	}
}

func TestInventoryServiceDepositRequiresAdjacentBank(t *testing.T) {
	userID := uuid.New()
	bankID := uuid.New()
	inventory := &memoryInventory{
		items: map[string]int64{"logs": 25},
	}
	service := NewInventoryService(
		inventory,
		&memoryBank{inventory: inventory},
		&memoryPlayerStore{
			player: domain.Player{UserID: userID, X: 12, Y: 12},
		},
		&memoryEntities{
			items: []domain.Entity{
				{
					ID:          bankID,
					UserID:      userID,
					Name:        "Bank",
					Type:        bankEntityType,
					ResourceKey: bankEntityResourceKey,
					X:           18,
					Y:           8,
					Width:       1,
					Height:      1,
					State:       resourceStateIdle,
				},
			},
		},
		nil,
	)
	service.now = func() time.Time { return time.Date(2026, time.May, 3, 12, 0, 0, 0, time.UTC) }

	_, err := service.Deposit(context.Background(), userID, bankID, "logs", 25)
	if err != ErrBankTooFar {
		t.Fatalf("expected ErrBankTooFar, got %v", err)
	}
}

type memoryBank struct {
	inventory *memoryInventory
	items      map[string]int64
}

func (m *memoryBank) ListBank(_ context.Context, _ uuid.UUID) ([]domain.InventoryItem, error) {
	result := make([]domain.InventoryItem, 0, len(m.items))
	for itemKey, quantity := range m.items {
		result = append(result, domain.InventoryItem{
			ItemKey:  itemKey,
			Quantity: quantity,
		})
	}
	return result, nil
}

func (m *memoryBank) DepositInventoryItem(_ context.Context, _ uuid.UUID, itemKey string, quantity int64) (int64, error) {
	if m.items == nil {
		m.items = map[string]int64{}
	}
	if m.inventory == nil || quantity <= 0 {
		return 0, nil
	}
	current := m.inventory.items[itemKey]
	moved := quantity
	if current < moved {
		moved = current
	}
	m.inventory.items[itemKey] = current - moved
	m.items[itemKey] += moved
	return moved, nil
}
