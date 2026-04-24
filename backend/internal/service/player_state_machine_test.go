package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestPlayerLifecycleMoveCancelsHarvest(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.April, 25, 10, 0, 0, 0, time.UTC)
	players := &memoryPlayerStore{
		player: domain.Player{UserID: userID, X: 1, Y: 1},
	}
	actions := &memoryActions{
		active: &domain.PlayerAction{
			ID:        uuid.New(),
			UserID:    userID,
			Type:      harvestActionType,
			Status:    "active",
			StartedAt: now.Add(-time.Second),
			EndsAt:    now.Add(time.Minute),
			NextTickAt: now.Add(
				time.Second,
			),
			TickIntervalMs: 1000,
			Metadata:       map[string]any{},
		},
	}
	service := NewPlayerService(
		players,
		&memoryMap{tileMap: domain.TileMap{UserID: userID, Width: 4, Height: 4, Tiles: filledTiles(16)}},
		&memoryEntities{},
		nil,
	)
	actionService := NewActionService(actions, &memoryInventory{}, nil, players, &memoryEntities{})
	actionService.now = func() time.Time { return now }
	service.SetActionService(actionService)
	service.now = func() time.Time { return now }

	player, err := service.Move(context.Background(), userID, 2, 1)
	if err != nil {
		t.Fatalf("Move returned error: %v", err)
	}
	if player.Movement == nil {
		t.Fatal("expected movement to start")
	}
	if actions.active == nil || actions.active.Status != "cancelled" {
		t.Fatalf("expected active harvest action to be cancelled, got %#v", actions.active)
	}
}

func TestActionLifecycleHarvestRejectedWhileMoving(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.April, 25, 10, 0, 0, 0, time.UTC)
	players := &memoryPlayerStore{
		player: domain.Player{
			UserID: userID,
			X:      1,
			Y:      1,
			Movement: &domain.PlayerMovement{
				FromX:               1,
				FromY:               1,
				TargetX:             2,
				TargetY:             1,
				Path:                []domain.Point{{X: 1, Y: 1}, {X: 2, Y: 1}},
				StartedAt:           now.Add(-500 * time.Millisecond),
				ArrivesAt:           now.Add(time.Second),
				SpeedTilesPerSecond: defaultPlayerSpeedTilesPerSecond,
			},
		},
	}
	entities := &memoryEntities{
		items: []domain.Entity{
			{
				ID:          uuid.New(),
				UserID:      userID,
				Type:        "resource",
				ResourceKey: "tree",
				State:       "idle",
				X:           2,
				Y:           2,
				Width:       1,
				Height:      1,
			},
		},
	}
	service := NewActionService(&memoryActions{}, &memoryInventory{}, nil, players, entities)
	service.now = func() time.Time { return now }

	_, err := service.StartHarvest(context.Background(), userID, entities.items[0].ID)
	if err != ErrPlayerIsMoving {
		t.Fatalf("expected ErrPlayerIsMoving, got %v", err)
	}
}

type memoryPlayerStore struct {
	player domain.Player
}

func (m *memoryPlayerStore) GetPlayer(_ context.Context, userID uuid.UUID) (domain.Player, error) {
	if m.player.UserID != userID {
		return domain.Player{}, nil
	}
	return m.player, nil
}

func (m *memoryPlayerStore) CreatePlayer(_ context.Context, player domain.Player) (domain.Player, error) {
	m.player = player
	return player, nil
}

func (m *memoryPlayerStore) SavePlayer(_ context.Context, player domain.Player) (domain.Player, error) {
	m.player = player
	return player, nil
}

type memoryEntities struct {
	items []domain.Entity
}

func (m *memoryEntities) ListEntities(_ context.Context, _ uuid.UUID) ([]domain.Entity, error) {
	return append([]domain.Entity(nil), m.items...), nil
}

func (m *memoryEntities) CreateEntity(_ context.Context, entity domain.Entity) (domain.Entity, error) {
	m.items = append(m.items, entity)
	return entity, nil
}
