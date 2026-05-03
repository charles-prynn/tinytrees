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
	actions    store.ActionStore
	inventory  store.InventoryStore
	skills     store.SkillStore
	players    store.PlayerStore
	entities   store.EntityStore
	events     store.EventStore
	transactor store.Transactor
	now        func() time.Time
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

func (s *ActionService) SetTransactor(transactor store.Transactor) {
	s.transactor = transactor
}

func (s *ActionService) SetEventStore(events store.EventStore) {
	s.events = events
}

func (s *ActionService) Current(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	return s.Resolve(ctx, userID)
}

func (s *ActionService) CancelActive(ctx context.Context, userID uuid.UUID) error {
	now := s.now()
	return s.withWriteStores(ctx, func(stores store.Stores) error {
		action, err := stores.Actions.GetActiveAction(ctx, userID)
		if err != nil || action == nil {
			return err
		}
		action.Status = "cancelled"
		if _, err := stores.Actions.SaveAction(ctx, *action); err != nil {
			return err
		}
		return s.appendEvents(ctx, stores, []domain.PlayerEvent{s.newActionEvent(*action, "action.cancelled", now)})
	})
}

func (s *ActionService) StartHarvest(ctx context.Context, userID uuid.UUID, entityID uuid.UUID) (domain.PlayerAction, error) {
	now := s.now()
	var created domain.PlayerAction
	err := s.withWriteStores(ctx, func(stores store.Stores) error {
		activeAction, err := stores.Actions.GetActiveAction(ctx, userID)
		if err != nil {
			return err
		}
		if activeAction != nil {
			return ErrActionInProgress
		}

		player, err := stores.Players.GetPlayer(ctx, userID)
		if err != nil {
			return err
		}
		if movement := player.Movement; movement != nil {
			if now.Before(movement.ArrivesAt) {
				return ErrPlayerIsMoving
			}
			player.X = movement.TargetX
			player.Y = movement.TargetY
			player.Movement = nil
			if _, err := stores.Players.SavePlayer(ctx, player); err != nil {
				return err
			}
		}

		entity, ok, err := s.entityByID(ctx, stores.Entities, userID, entityID)
		if err != nil {
			return err
		}
		if !ok || !isHarvestableEntity(entity) || !isAdjacentToEntity(domain.Point{X: player.X, Y: player.Y}, entity) {
			return ErrInvalidHarvestTarget
		}

		skillKey := harvestSkillKey(entity)
		currentLevel := int64(0)
		if stores.Skills != nil && skillKey != "" {
			skills, err := stores.Skills.ListSkills(ctx, userID)
			if err != nil {
				return err
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
		requiredLevel := requiredLevelForEntity(entity)
		if currentLevel < requiredLevel {
			return ErrInsufficientLevel
		}

		tickInterval := harvestTickInterval(currentLevel, requiredLevel)
		harvestDuration := harvestDurationForEntity(entity)
		created = domain.PlayerAction{
			ID:             uuid.New(),
			UserID:         userID,
			Type:           harvestActionType,
			EntityID:       &entityID,
			Status:         "active",
			StartedAt:      now,
			EndsAt:         now.Add(harvestDuration),
			NextTickAt:     minTime(now.Add(tickInterval), now.Add(harvestDuration)),
			TickIntervalMs: int(tickInterval / time.Millisecond),
			Metadata: map[string]any{
				"resource_key":             entity.ResourceKey,
				"reward_item_key":          harvestRewardItemKey(entity),
				"reward_quantity":          harvestRewardQuantity(entity),
				"success_chance":           harvestSuccessChance(entity),
				"skill_key":                skillKey,
				"xp_per_reward":            harvestXPPerReward(entity),
				"ticks_processed":          0,
				"rewards_granted":          0,
				"xp_granted":               0,
				"current_level":            currentLevel,
				"duration_seconds":         harvestDuration.Seconds(),
				"harvest_duration_seconds": int64(harvestDuration / time.Second),
				"required_level":           requiredLevel,
			},
		}
		created, err = stores.Actions.CreateAction(ctx, created)
		if err != nil {
			return err
		}
		return s.appendEvents(ctx, stores, []domain.PlayerEvent{s.newActionEvent(created, "action.started", now)})
	})
	return created, err
}

func (s *ActionService) Resolve(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	return s.actions.GetActiveAction(ctx, userID)
}

func (s *ActionService) ProcessDue(ctx context.Context, limit int) (int, error) {
	if limit <= 0 {
		limit = 1
	}

	processed := 0
	for processed < limit {
		handled, err := s.processNextDue(ctx)
		if err != nil {
			return processed, err
		}
		if !handled {
			return processed, nil
		}
		processed++
	}
	return processed, nil
}

func (s *ActionService) processNextDue(ctx context.Context) (bool, error) {
	now := s.now()
	if s.transactor != nil {
		handled := false
		err := s.transactor.WithinTx(ctx, func(stores store.Stores) error {
			action, err := stores.Actions.ClaimNextDueAction(ctx, now)
			if err != nil {
				return err
			}
			if action == nil {
				return nil
			}
			handled = true
			return s.advanceAction(ctx, stores, action, now)
		})
		return handled, err
	}

	action, err := s.actions.ClaimNextDueAction(ctx, now)
	if err != nil {
		return false, err
	}
	if action == nil {
		return false, nil
	}
	return true, s.advanceAction(ctx, s.baseStores(), action, now)
}

func (s *ActionService) advanceAction(ctx context.Context, stores store.Stores, action *domain.PlayerAction, now time.Time) error {
	if action == nil {
		return nil
	}
	if action.Type != harvestActionType {
		if !now.Before(action.EndsAt) {
			action.Status = "completed"
			if _, err := stores.Actions.SaveAction(ctx, *action); err != nil {
				return err
			}
			return s.appendEvents(ctx, stores, []domain.PlayerEvent{s.newActionEvent(*action, "action.completed", now)})
		}
		return nil
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
	startingLevel := currentLevel

	for !action.NextTickAt.After(now) && !action.NextTickAt.After(action.EndsAt) {
		ticksProcessed++
		if randomUnitFloat() < successChance {
			addedQuantity, err := stores.Inventory.AddInventoryItem(ctx, action.UserID, itemKey, rewardQuantity)
			if err != nil {
				return err
			}
			rewardsGranted += addedQuantity
			if addedQuantity > 0 && stores.Skills != nil && skillKey != "" && xpPerReward > 0 {
				skill, err := stores.Skills.AddXP(ctx, action.UserID, skillKey, xpPerReward*addedQuantity)
				if err != nil {
					return err
				}
				xpGranted += xpPerReward * addedQuantity
				if currentLevel > 0 && int64(skill.Level) > currentLevel {
					levelUps += int64(skill.Level) - currentLevel
				}
				currentLevel = int64(skill.Level)
			}
		}
		if !action.NextTickAt.Before(action.EndsAt) {
			break
		}
		action.NextTickAt = minTime(action.NextTickAt.Add(tickInterval), action.EndsAt)
	}

	action.Metadata["ticks_processed"] = ticksProcessed
	action.Metadata["rewards_granted"] = rewardsGranted
	action.Metadata["xp_granted"] = xpGranted
	action.Metadata["level_ups"] = levelUps
	if currentLevel > 0 {
		action.Metadata["current_level"] = currentLevel
	}

	emitted := []domain.PlayerEvent{}
	if currentLevel > startingLevel && skillKey != "" {
		emitted = append(emitted, s.newSkillLevelUpEvent(*action, skillKey, startingLevel, currentLevel, now))
	}

	if !now.Before(action.EndsAt) {
		action.Status = "completed"
		if action.EntityID != nil && stores.Entities != nil {
			entity, ok, err := s.entityByID(ctx, stores.Entities, action.UserID, *action.EntityID)
			if err != nil {
				return err
			}
			if ok && entity.State != resourceStateDepleted {
				if entity, err = depleteResourceNode(ctx, stores.Entities, entity, now); err != nil {
					return err
				}
				emitted = append(emitted, s.newResourceEvent(*action, entity, "resource.depleted", now))
			}
		}
		emitted = append(emitted, s.newActionEvent(*action, "action.completed", now))
	}

	if _, err := stores.Actions.SaveAction(ctx, *action); err != nil {
		return err
	}
	return s.appendEvents(ctx, stores, emitted)
}

func (s *ActionService) appendEvents(ctx context.Context, stores store.Stores, events []domain.PlayerEvent) error {
	if len(events) == 0 || stores.Events == nil {
		return nil
	}
	_, err := stores.Events.AppendEvents(ctx, events)
	return err
}

func (s *ActionService) withWriteStores(ctx context.Context, fn func(store.Stores) error) error {
	if s.transactor != nil {
		return s.transactor.WithinTx(ctx, fn)
	}
	return fn(s.baseStores())
}

func (s *ActionService) baseStores() store.Stores {
	return store.Stores{
		Actions:   s.actions,
		Entities:  s.entities,
		Events:    s.events,
		Inventory: s.inventory,
		Players:   s.players,
		Skills:    s.skills,
	}
}

func (s *ActionService) entityByID(ctx context.Context, entityStore store.EntityStore, userID uuid.UUID, entityID uuid.UUID) (domain.Entity, bool, error) {
	entities, err := entityStore.ListEntities(ctx, userID)
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

func (s *ActionService) newActionEvent(action domain.PlayerAction, eventType string, now time.Time) domain.PlayerEvent {
	aggregateID := action.ID
	payload := map[string]any{
		"action_id":        action.ID,
		"action_type":      action.Type,
		"status":           action.Status,
		"entity_id":        action.EntityID,
		"resource_key":     stringMetadata(action.Metadata, "resource_key", ""),
		"started_at":       action.StartedAt,
		"ends_at":          action.EndsAt,
		"next_tick_at":     action.NextTickAt,
		"rewards_granted":  int64Metadata(action.Metadata, "rewards_granted", 0),
		"xp_granted":       int64Metadata(action.Metadata, "xp_granted", 0),
		"level_ups":        int64Metadata(action.Metadata, "level_ups", 0),
		"current_level":    int64Metadata(action.Metadata, "current_level", 0),
		"occurred_at":      now,
		"action_metadata":  cloneMetadata(action.Metadata),
		"tick_interval_ms": action.TickIntervalMs,
	}
	return domain.PlayerEvent{
		UserID:        action.UserID,
		AggregateType: "action",
		AggregateID:   &aggregateID,
		EventType:     eventType,
		Payload:       payload,
	}
}

func (s *ActionService) newResourceEvent(action domain.PlayerAction, entity domain.Entity, eventType string, now time.Time) domain.PlayerEvent {
	aggregateID := entity.ID
	return domain.PlayerEvent{
		UserID:        action.UserID,
		AggregateType: "entity",
		AggregateID:   &aggregateID,
		EventType:     eventType,
		Payload: map[string]any{
			"action_id":    action.ID,
			"entity_id":    entity.ID,
			"resource_key": entity.ResourceKey,
			"state":        entity.State,
			"occurred_at":  now,
		},
	}
}

func (s *ActionService) newSkillLevelUpEvent(action domain.PlayerAction, skillKey string, fromLevel int64, toLevel int64, now time.Time) domain.PlayerEvent {
	return domain.PlayerEvent{
		UserID:        action.UserID,
		AggregateType: "skill",
		EventType:     "skill.level_up",
		Payload: map[string]any{
			"action_id":     action.ID,
			"skill_key":     skillKey,
			"from_level":    fromLevel,
			"to_level":      toLevel,
			"levels_gained": toLevel - fromLevel,
			"occurred_at":   now,
		},
	}
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

func minTime(a time.Time, b time.Time) time.Time {
	if a.Before(b) {
		return a
	}
	return b
}

func cloneMetadata(metadata map[string]any) map[string]any {
	if metadata == nil {
		return map[string]any{}
	}
	cloned := make(map[string]any, len(metadata))
	for key, value := range metadata {
		cloned[key] = value
	}
	return cloned
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
