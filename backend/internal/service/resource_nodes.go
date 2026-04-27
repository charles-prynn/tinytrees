package service

import (
	"context"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

const (
	resourceStateIdle             = "idle"
	resourceStateDepleted         = "depleted"
	resourceNodeTargetCount       = 10
	resourceStumpLifetime         = 30 * time.Second
	defaultResourceSkillKey       = "woodcutting"
	defaultResourceRewardQuantity = int64(1)
)

type treeDefinition struct {
	Key           string
	Name          string
	RequiredLevel int64
	RewardItemKey string
	XPPerReward   int64
}

var (
	treeDefinitions = []treeDefinition{
		{Key: "tree", Name: "Tree", RequiredLevel: 1, RewardItemKey: "logs", XPPerReward: 25},
		{Key: "oak_tree", Name: "Oak Tree", RequiredLevel: 15, RewardItemKey: "oak_logs", XPPerReward: 38},
		{Key: "willow_tree", Name: "Willow Tree", RequiredLevel: 30, RewardItemKey: "willow_logs", XPPerReward: 68},
		{Key: "maple_tree", Name: "Maple Tree", RequiredLevel: 45, RewardItemKey: "maple_logs", XPPerReward: 100},
		{Key: "yew_tree", Name: "Yew Tree", RequiredLevel: 60, RewardItemKey: "yew_logs", XPPerReward: 175},
		{Key: "magic_tree", Name: "Magic Tree", RequiredLevel: 75, RewardItemKey: "magic_logs", XPPerReward: 250},
	}
	treeTargetCounts = map[string]int{
		"tree":        3,
		"oak_tree":    2,
		"willow_tree": 2,
		"maple_tree":  1,
		"yew_tree":    1,
		"magic_tree":  1,
	}
	resourceSpawnSlots = []domain.Point{
		{X: 8, Y: 8}, {X: 14, Y: 6}, {X: 20, Y: 8}, {X: 27, Y: 7}, {X: 34, Y: 8},
		{X: 41, Y: 7}, {X: 48, Y: 8}, {X: 55, Y: 7}, {X: 12, Y: 14}, {X: 19, Y: 14},
		{X: 26, Y: 13}, {X: 33, Y: 14}, {X: 40, Y: 13}, {X: 47, Y: 14}, {X: 54, Y: 13},
		{X: 9, Y: 21}, {X: 16, Y: 23}, {X: 23, Y: 21}, {X: 30, Y: 23}, {X: 37, Y: 21},
		{X: 44, Y: 23}, {X: 51, Y: 21}, {X: 58, Y: 23}, {X: 32, Y: 16},
	}
	treeDefinitionByKey = map[string]treeDefinition{}
)

func init() {
	for _, definition := range treeDefinitions {
		treeDefinitionByKey[definition.Key] = definition
	}
}

func ensureResourceNodes(ctx context.Context, entityStore store.EntityStore, userID uuid.UUID, now time.Time) ([]domain.Entity, error) {
	entities, err := entityStore.ListEntities(ctx, userID)
	if err != nil {
		return nil, err
	}

	filtered := make([]domain.Entity, 0, len(entities))
	changed := false
	for _, entity := range entities {
		if entity.State == resourceStateDepleted && stumpExpired(entity, now) {
			if err := entityStore.DeleteEntity(ctx, userID, entity.ID); err != nil {
				return nil, err
			}
			changed = true
			continue
		}
		filtered = append(filtered, entity)
	}

	missing := missingTreeTypes(filtered)
	for _, resourceKey := range missing {
		entity, ok := spawnResourceEntity(userID, filtered, resourceKey)
		if !ok {
			break
		}
		created, err := entityStore.CreateEntity(ctx, entity)
		if err != nil {
			return nil, err
		}
		filtered = append(filtered, created)
		changed = true
	}

	if !changed {
		return filtered, nil
	}
	return filtered, nil
}

func depleteResourceNode(ctx context.Context, entityStore store.EntityStore, entity domain.Entity, now time.Time) (domain.Entity, error) {
	if entity.Metadata == nil {
		entity.Metadata = map[string]any{}
	}
	entity.State = resourceStateDepleted
	entity.Metadata["stump_expires_at"] = now.Add(resourceStumpLifetime).Format(time.RFC3339Nano)
	entity.Metadata["depleted_at"] = now.Format(time.RFC3339Nano)
	return entityStore.SaveEntity(ctx, entity)
}

func resourceDefinition(entity domain.Entity) treeDefinition {
	if definition, ok := treeDefinitionByKey[entity.ResourceKey]; ok {
		return definition
	}
	return treeDefinitions[0]
}

func buildResourceEntity(userID uuid.UUID, slot domain.Point, definition treeDefinition) domain.Entity {
	return domain.Entity{
		ID:          uuid.New(),
		UserID:      userID,
		Name:        definition.Name,
		Type:        "resource",
		ResourceKey: definition.Key,
		X:           slot.X,
		Y:           slot.Y,
		Width:       1,
		Height:      1,
		SpriteGID:   5,
		State:       resourceStateIdle,
		Metadata: map[string]any{
			"reward_item_key": definition.RewardItemKey,
			"reward_quantity": defaultResourceRewardQuantity,
			"skill_key":       defaultResourceSkillKey,
			"xp_per_reward":   definition.XPPerReward,
			"required_level":  definition.RequiredLevel,
		},
	}
}

func missingTreeTypes(entities []domain.Entity) []string {
	activeCounts := map[string]int{}
	activeTotal := 0
	for _, entity := range entities {
		if entity.Type != "resource" || entity.State == resourceStateDepleted {
			continue
		}
		activeCounts[entity.ResourceKey]++
		activeTotal++
	}
	if activeTotal >= resourceNodeTargetCount {
		return nil
	}

	missing := make([]string, 0, resourceNodeTargetCount-activeTotal)
	for _, definition := range treeDefinitions {
		target := treeTargetCounts[definition.Key]
		current := activeCounts[definition.Key]
		for current < target && len(missing) < resourceNodeTargetCount-activeTotal {
			missing = append(missing, definition.Key)
			current++
		}
	}
	return missing
}

func spawnResourceEntity(userID uuid.UUID, entities []domain.Entity, resourceKey string) (domain.Entity, bool) {
	definition, ok := treeDefinitionByKey[resourceKey]
	if !ok {
		definition = treeDefinitions[0]
	}

	occupied := map[domain.Point]struct{}{}
	for _, entity := range entities {
		occupied[domain.Point{X: entity.X, Y: entity.Y}] = struct{}{}
	}

	freeSlots := make([]domain.Point, 0, len(resourceSpawnSlots))
	for _, slot := range resourceSpawnSlots {
		if _, ok := occupied[slot]; ok {
			continue
		}
		freeSlots = append(freeSlots, slot)
	}
	if len(freeSlots) == 0 {
		return domain.Entity{}, false
	}

	slot := freeSlots[randomIndex(len(freeSlots))]
	return buildResourceEntity(userID, slot, definition), true
}

func stumpExpired(entity domain.Entity, now time.Time) bool {
	expiresAtRaw := stringMetadata(entity.Metadata, "stump_expires_at", "")
	if expiresAtRaw == "" {
		return true
	}
	expiresAt, err := time.Parse(time.RFC3339Nano, expiresAtRaw)
	if err != nil {
		return true
	}
	return !now.Before(expiresAt)
}

func requiredLevelForEntity(entity domain.Entity) int64 {
	return int64Metadata(entity.Metadata, "required_level", resourceDefinition(entity).RequiredLevel)
}

func randomIndex(length int) int {
	if length <= 1 {
		return 0
	}
	return int(randomUnitFloat() * float64(length))
}
