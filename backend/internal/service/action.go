package service

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"math"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

const (
	harvestActionType            = "harvest"
	defaultHarvestDuration       = 5 * time.Minute
	defaultHarvestTickInterval   = 3 * time.Second
	defaultHarvestSuccessChance  = 0.35
	defaultHarvestRewardItemKey  = "wood"
	defaultHarvestRewardQuantity = int64(1)
)

var (
	ErrActionInProgress     = errors.New("an action is already in progress")
	ErrInvalidHarvestTarget = errors.New("resource cannot be harvested")
	ErrPlayerIsMoving       = errors.New("player must stop moving before starting an action")
)

type ActionService struct {
	actions   store.ActionStore
	inventory store.InventoryStore
	players   store.PlayerStore
	entities  store.EntityStore
	now       func() time.Time
}

func NewActionService(actions store.ActionStore, inventory store.InventoryStore, players store.PlayerStore, entities store.EntityStore) *ActionService {
	return &ActionService{
		actions:   actions,
		inventory: inventory,
		players:   players,
		entities:  entities,
		now:       func() time.Time { return time.Now().UTC() },
	}
}

func (s *ActionService) Current(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	return s.Resolve(ctx, userID)
}

func (s *ActionService) CancelActive(ctx context.Context, userID uuid.UUID) error {
	action, err := s.Resolve(ctx, userID)
	if err != nil || action == nil {
		return err
	}
	action.Status = "cancelled"
	_, err = s.actions.SaveAction(ctx, *action)
	return err
}

func (s *ActionService) StartHarvest(ctx context.Context, userID uuid.UUID, entityID uuid.UUID) (domain.PlayerAction, error) {
	if _, err := s.Resolve(ctx, userID); err != nil {
		return domain.PlayerAction{}, err
	}
	active, err := s.actions.GetActiveAction(ctx, userID)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	if active != nil {
		return domain.PlayerAction{}, ErrActionInProgress
	}

	now := s.now()
	player, err := s.players.GetPlayer(ctx, userID)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	if player.Movement != nil {
		if now.Before(player.Movement.ArrivesAt) {
			return domain.PlayerAction{}, ErrPlayerIsMoving
		}
		player.X = player.Movement.TargetX
		player.Y = player.Movement.TargetY
		player.Movement = nil
		if _, err := s.players.SavePlayer(ctx, player); err != nil {
			return domain.PlayerAction{}, err
		}
	}

	entity, ok, err := s.entityByID(ctx, userID, entityID)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	if !ok || !isHarvestableEntity(entity) || !isAdjacentToEntity(domain.Point{X: player.X, Y: player.Y}, entity) {
		return domain.PlayerAction{}, ErrInvalidHarvestTarget
	}

	action := domain.PlayerAction{
		ID:             uuid.New(),
		UserID:         userID,
		Type:           harvestActionType,
		EntityID:       &entityID,
		Status:         "active",
		StartedAt:      now,
		EndsAt:         now.Add(defaultHarvestDuration),
		NextTickAt:     now.Add(defaultHarvestTickInterval),
		TickIntervalMs: int(defaultHarvestTickInterval / time.Millisecond),
		Metadata: map[string]any{
			"resource_key":     entity.ResourceKey,
			"reward_item_key":  harvestRewardItemKey(entity),
			"reward_quantity":  harvestRewardQuantity(entity),
			"success_chance":   harvestSuccessChance(entity),
			"ticks_processed":  0,
			"rewards_granted":  0,
			"duration_seconds": int(defaultHarvestDuration / time.Second),
		},
	}
	return s.actions.CreateAction(ctx, action)
}

func (s *ActionService) Resolve(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	action, err := s.actions.GetActiveAction(ctx, userID)
	if err != nil || action == nil {
		return action, err
	}
	if action.Type != harvestActionType {
		return action, nil
	}

	now := s.now()
	if now.Before(action.NextTickAt) && now.Before(action.EndsAt) {
		return action, nil
	}

	itemKey := stringMetadata(action.Metadata, "reward_item_key", defaultHarvestRewardItemKey)
	rewardQuantity := int64Metadata(action.Metadata, "reward_quantity", defaultHarvestRewardQuantity)
	successChance := floatMetadata(action.Metadata, "success_chance", defaultHarvestSuccessChance)
	tickInterval := time.Duration(action.TickIntervalMs) * time.Millisecond
	if tickInterval <= 0 {
		tickInterval = defaultHarvestTickInterval
	}

	ticksProcessed := int64Metadata(action.Metadata, "ticks_processed", 0)
	rewardsGranted := int64Metadata(action.Metadata, "rewards_granted", 0)
	for !action.NextTickAt.After(now) && !action.NextTickAt.After(action.EndsAt) {
		ticksProcessed++
		if randomUnitFloat() < successChance {
			if err := s.inventory.AddInventoryItem(ctx, userID, itemKey, rewardQuantity); err != nil {
				return nil, err
			}
			rewardsGranted += rewardQuantity
		}
		action.NextTickAt = action.NextTickAt.Add(tickInterval)
	}

	action.Metadata["ticks_processed"] = ticksProcessed
	action.Metadata["rewards_granted"] = rewardsGranted
	if !now.Before(action.EndsAt) {
		action.Status = "completed"
	}

	saved, err := s.actions.SaveAction(ctx, *action)
	if err != nil {
		return nil, err
	}
	if saved.Status != "active" {
		return nil, nil
	}
	return &saved, nil
}

func (s *ActionService) entityByID(ctx context.Context, userID uuid.UUID, entityID uuid.UUID) (domain.Entity, bool, error) {
	entities, err := s.entities.ListEntities(ctx, userID)
	if err != nil {
		return domain.Entity{}, false, err
	}
	for _, entity := range entities {
		if entity.ID == entityID {
			return entity, true, nil
		}
	}
	return domain.Entity{}, false, nil
}

func isHarvestableEntity(entity domain.Entity) bool {
	return entity.Type == "resource" && entity.State != "depleted"
}

func isAdjacentToEntity(player domain.Point, entity domain.Entity) bool {
	left := entity.X
	top := entity.Y
	right := entity.X + max(1, entity.Width) - 1
	bottom := entity.Y + max(1, entity.Height) - 1
	if player.X >= left && player.X <= right && player.Y >= top && player.Y <= bottom {
		return false
	}
	dx := 0
	if player.X < left {
		dx = left - player.X
	} else if player.X > right {
		dx = player.X - right
	}
	dy := 0
	if player.Y < top {
		dy = top - player.Y
	} else if player.Y > bottom {
		dy = player.Y - bottom
	}
	return dx <= 1 && dy <= 1
}

func harvestRewardItemKey(entity domain.Entity) string {
	return stringMetadata(entity.Metadata, "reward_item_key", defaultHarvestRewardItemKey)
}

func harvestRewardQuantity(entity domain.Entity) int64 {
	return int64Metadata(entity.Metadata, "reward_quantity", defaultHarvestRewardQuantity)
}

func harvestSuccessChance(entity domain.Entity) float64 {
	return math.Max(0, math.Min(1, floatMetadata(entity.Metadata, "success_chance", defaultHarvestSuccessChance)))
}

func stringMetadata(metadata map[string]any, key string, fallback string) string {
	if value, ok := metadata[key].(string); ok && value != "" {
		return value
	}
	return fallback
}

func int64Metadata(metadata map[string]any, key string, fallback int64) int64 {
	switch value := metadata[key].(type) {
	case int:
		return int64(value)
	case int64:
		return value
	case float64:
		return int64(value)
	case jsonNumber:
		number, err := value.Int64()
		if err == nil {
			return number
		}
	}
	return fallback
}

func floatMetadata(metadata map[string]any, key string, fallback float64) float64 {
	switch value := metadata[key].(type) {
	case float32:
		return float64(value)
	case float64:
		return value
	case int:
		return float64(value)
	case int64:
		return float64(value)
	case jsonNumber:
		number, err := value.Float64()
		if err == nil {
			return number
		}
	}
	return fallback
}

type jsonNumber interface {
	Int64() (int64, error)
	Float64() (float64, error)
}

func randomUnitFloat() float64 {
	var data [8]byte
	if _, err := rand.Read(data[:]); err != nil {
		return 1
	}
	return float64(binary.BigEndian.Uint64(data[:])) / float64(^uint64(0))
}
