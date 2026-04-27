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
	defaultHarvestDuration       = 8 * time.Second
	defaultHarvestTickInterval   = 5 * time.Second
	defaultHarvestSuccessChance  = 1.0
	defaultHarvestRewardItemKey  = "wood"
	defaultHarvestRewardQuantity = int64(1)
	defaultHarvestSkillKey       = "woodcutting"
	defaultHarvestXPPerReward    = int64(25)
	minHarvestTickInterval       = 1200 * time.Millisecond
)

var (
	ErrActionInProgress     = errors.New("an action is already in progress")
	ErrInvalidHarvestTarget = errors.New("resource cannot be harvested")
	ErrPlayerIsMoving       = errors.New("player must stop moving before starting an action")
	ErrInsufficientLevel    = errors.New("woodcutting level is too low for this tree")
)

type ActionService struct {
	actions   store.ActionStore
	inventory store.InventoryStore
	skills    store.SkillStore
	players   store.PlayerStore
	entities  store.EntityStore
	now       func() time.Time
}

func NewActionService(actions store.ActionStore, inventory store.InventoryStore, skills store.SkillStore, players store.PlayerStore, entities store.EntityStore) *ActionService {
	return &ActionService{
		actions:   actions,
		inventory: inventory,
		skills:    skills,
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
	activeAction, err := s.Resolve(ctx, userID)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	if activeAction != nil {
		return domain.PlayerAction{}, ErrActionInProgress
	}

	now := s.now()
	player, err := s.players.GetPlayer(ctx, userID)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	if movement := player.Movement; movement != nil {
		if now.Before(movement.ArrivesAt) {
			return domain.PlayerAction{}, ErrPlayerIsMoving
		}
		player.X = movement.TargetX
		player.Y = movement.TargetY
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

	skillKey := harvestSkillKey(entity)
	currentLevel := int64(0)
	if s.skills != nil && skillKey != "" {
		skills, err := s.skills.ListSkills(ctx, userID)
		if err != nil {
			return domain.PlayerAction{}, err
		}
		for _, skill := range skills {
			if skill.SkillKey == skillKey {
				currentLevel = int64(skill.Level)
				break
			}
		}
		if currentLevel == 0 {
			currentLevel = 1
		}
	}
	if currentLevel < requiredLevelForEntity(entity) {
		return domain.PlayerAction{}, ErrInsufficientLevel
	}

	tickInterval := harvestTickInterval(currentLevel, requiredLevelForEntity(entity))

	action := domain.PlayerAction{
		ID:             uuid.New(),
		UserID:         userID,
		Type:           harvestActionType,
		EntityID:       &entityID,
		Status:         "active",
		StartedAt:      now,
		EndsAt:         now.Add(tickInterval),
		NextTickAt:     now.Add(tickInterval),
		TickIntervalMs: int(tickInterval / time.Millisecond),
		Metadata: map[string]any{
			"resource_key":      entity.ResourceKey,
			"reward_item_key":   harvestRewardItemKey(entity),
			"reward_quantity":   harvestRewardQuantity(entity),
			"success_chance":    harvestSuccessChance(entity),
			"skill_key":         skillKey,
			"xp_per_reward":     harvestXPPerReward(entity),
			"ticks_processed":   0,
			"rewards_granted":   0,
			"xp_granted":        0,
			"current_level":     currentLevel,
			"duration_seconds":  tickInterval.Milliseconds() / 1000.0,
			"deplete_on_reward": true,
			"required_level":    requiredLevelForEntity(entity),
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
	skillKey := stringMetadata(action.Metadata, "skill_key", defaultHarvestSkillKey)
	xpPerReward := int64Metadata(action.Metadata, "xp_per_reward", defaultHarvestXPPerReward)
	tickInterval := time.Duration(action.TickIntervalMs) * time.Millisecond
	if tickInterval <= 0 {
		tickInterval = defaultHarvestTickInterval
	}

	ticksProcessed := int64Metadata(action.Metadata, "ticks_processed", 0)
	rewardsGranted := int64Metadata(action.Metadata, "rewards_granted", 0)
	xpGranted := int64Metadata(action.Metadata, "xp_granted", 0)
	levelUps := int64Metadata(action.Metadata, "level_ups", 0)
	currentLevel := int64Metadata(action.Metadata, "current_level", 0)
	depleteOnReward := boolMetadata(action.Metadata, "deplete_on_reward", false)
	for !action.NextTickAt.After(now) && !action.NextTickAt.After(action.EndsAt) {
		ticksProcessed++
		if randomUnitFloat() < successChance {
			if err := s.inventory.AddInventoryItem(ctx, userID, itemKey, rewardQuantity); err != nil {
				return nil, err
			}
			rewardsGranted += rewardQuantity
			if s.skills != nil && skillKey != "" && xpPerReward > 0 {
				skill, err := s.skills.AddXP(ctx, userID, skillKey, xpPerReward*rewardQuantity)
				if err != nil {
					return nil, err
				}
				xpGranted += xpPerReward * rewardQuantity
				if currentLevel > 0 && int64(skill.Level) > currentLevel {
					levelUps += int64(skill.Level) - currentLevel
				}
				currentLevel = int64(skill.Level)
			}
			if depleteOnReward && action.EntityID != nil && s.entities != nil {
				entity, ok, err := s.entityByID(ctx, userID, *action.EntityID)
				if err != nil {
					return nil, err
				}
				if ok && entity.State != resourceStateDepleted {
					if _, err := depleteResourceNode(ctx, s.entities, entity, now); err != nil {
						return nil, err
					}
				}
				action.Status = "completed"
				action.NextTickAt = action.EndsAt
				break
			}
		}
		action.NextTickAt = action.NextTickAt.Add(tickInterval)
	}

	action.Metadata["ticks_processed"] = ticksProcessed
	action.Metadata["rewards_granted"] = rewardsGranted
	action.Metadata["xp_granted"] = xpGranted
	action.Metadata["level_ups"] = levelUps
	if currentLevel > 0 {
		action.Metadata["current_level"] = currentLevel
	}
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
	return entity.Type == "resource" && entity.State != resourceStateDepleted
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

func harvestSkillKey(entity domain.Entity) string {
	return stringMetadata(entity.Metadata, "skill_key", defaultHarvestSkillKey)
}

func harvestXPPerReward(entity domain.Entity) int64 {
	return int64Metadata(entity.Metadata, "xp_per_reward", defaultHarvestXPPerReward)
}

func harvestTickInterval(currentLevel int64, requiredLevel int64) time.Duration {
	levelBonus := currentLevel - requiredLevel
	if levelBonus < 0 {
		levelBonus = 0
	}
	interval := defaultHarvestTickInterval - time.Duration(levelBonus)*45*time.Millisecond
	if interval < minHarvestTickInterval {
		return minHarvestTickInterval
	}
	return interval
}

func stringMetadata(metadata map[string]any, key string, fallback string) string {
	if metadata == nil {
		return fallback
	}
	if value, ok := metadata[key].(string); ok && value != "" {
		return value
	}
	return fallback
}

func int64Metadata(metadata map[string]any, key string, fallback int64) int64 {
	if metadata == nil {
		return fallback
	}
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
	if metadata == nil {
		return fallback
	}
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

func boolMetadata(metadata map[string]any, key string, fallback bool) bool {
	if metadata == nil {
		return fallback
	}
	value, ok := metadata[key].(bool)
	if !ok {
		return fallback
	}
	return value
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
