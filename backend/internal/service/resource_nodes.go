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
	resourceNodeTargetCount       = 100
	resourceStumpLifetime         = 30 * time.Second
	defaultResourceSkillKey       = "woodcutting"
	defaultResourceRewardQuantity = int64(1)
	minForestTreeGapTiles         = 3
)

type treeDefinition struct {
	Key             string
	Name            string
	RequiredLevel   int64
	RewardItemKey   string
	XPPerReward     int64
	HarvestDuration time.Duration
}

type forestArea struct {
	MinX int
	MaxX int
	MinY int
	MaxY int
}

var (
	treeDefinitions = []treeDefinition{
		{Key: "tree", Name: "Tree", RequiredLevel: 1, RewardItemKey: "logs", XPPerReward: 25, HarvestDuration: 10 * time.Minute},
		{Key: "oak_tree", Name: "Oak Tree", RequiredLevel: 15, RewardItemKey: "oak_logs", XPPerReward: 38, HarvestDuration: 15 * time.Minute},
		{Key: "willow_tree", Name: "Willow Tree", RequiredLevel: 30, RewardItemKey: "willow_logs", XPPerReward: 68, HarvestDuration: 20 * time.Minute},
		{Key: "maple_tree", Name: "Maple Tree", RequiredLevel: 45, RewardItemKey: "maple_logs", XPPerReward: 100, HarvestDuration: 30 * time.Minute},
		{Key: "yew_tree", Name: "Yew Tree", RequiredLevel: 60, RewardItemKey: "yew_logs", XPPerReward: 175, HarvestDuration: 45 * time.Minute},
		{Key: "magic_tree", Name: "Magic Tree", RequiredLevel: 75, RewardItemKey: "magic_logs", XPPerReward: 250, HarvestDuration: time.Hour},
	}

	treeTargetWeights = map[string]int{
		"tree":        3,
		"oak_tree":    2,
		"willow_tree": 2,
		"maple_tree":  1,
		"yew_tree":    1,
		"magic_tree":  1,
	}

	treeForestAreas = map[string]forestArea{
		"tree":        {MinX: 2, MaxX: 25, MinY: 2, MaxY: 13},
		"oak_tree":    {MinX: 29, MaxX: 43, MinY: 2, MaxY: 13},
		"willow_tree": {MinX: 47, MaxX: 61, MinY: 2, MaxY: 13},
		"maple_tree":  {MinX: 2, MaxX: 18, MinY: 18, MaxY: 29},
		"yew_tree":    {MinX: 23, MaxX: 39, MinY: 18, MaxY: 29},
		"magic_tree":  {MinX: 44, MaxX: 60, MinY: 18, MaxY: 29},
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
			"reward_item_key":          definition.RewardItemKey,
			"reward_quantity":          defaultResourceRewardQuantity,
			"skill_key":                defaultResourceSkillKey,
			"xp_per_reward":            definition.XPPerReward,
			"required_level":           definition.RequiredLevel,
			"harvest_duration_seconds": int64(definition.HarvestDuration / time.Second),
		},
	}
}

func missingTreeTypes(entities []domain.Entity) []string {
	treeTargetCounts := scaledTreeTargetCounts(resourceNodeTargetCount)
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

func scaledTreeTargetCounts(total int) map[string]int {
	if total <= 0 {
		return map[string]int{}
	}

	weightTotal := 0
	for _, definition := range treeDefinitions {
		weightTotal += treeTargetWeights[definition.Key]
	}
	if weightTotal <= 0 {
		return map[string]int{}
	}

	counts := make(map[string]int, len(treeDefinitions))
	remainders := make([]struct {
		key       string
		remainder int
	}, 0, len(treeDefinitions))
	assigned := 0

	for _, definition := range treeDefinitions {
		weight := treeTargetWeights[definition.Key]
		scaled := total * weight
		count := scaled / weightTotal
		counts[definition.Key] = count
		assigned += count
		remainders = append(remainders, struct {
			key       string
			remainder int
		}{
			key:       definition.Key,
			remainder: scaled % weightTotal,
		})
	}

	for assigned < total {
		bestIndex := 0
		for index := 1; index < len(remainders); index++ {
			if remainders[index].remainder > remainders[bestIndex].remainder {
				bestIndex = index
			}
		}
		counts[remainders[bestIndex].key]++
		remainders[bestIndex].remainder = -1
		assigned++
	}

	return counts
}

func spawnResourceEntity(userID uuid.UUID, entities []domain.Entity, resourceKey string) (domain.Entity, bool) {
	definition, ok := treeDefinitionByKey[resourceKey]
	if !ok {
		definition = treeDefinitions[0]
	}
	forest, ok := treeForestAreas[definition.Key]
	if !ok {
		return domain.Entity{}, false
	}

	occupied := make([]domain.Point, 0, len(entities))
	for _, entity := range entities {
		occupied = append(occupied, domain.Point{X: entity.X, Y: entity.Y})
	}

	candidates := forestCandidates(forest, minForestTreeGapTiles)
	shufflePoints(candidates)
	for _, slot := range candidates {
		if !canPlaceForestTree(slot, occupied, minForestTreeGapTiles) {
			continue
		}
		return buildResourceEntity(userID, slot, definition), true
	}
	return domain.Entity{}, false
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

func harvestDurationForEntity(entity domain.Entity) time.Duration {
	definition := resourceDefinition(entity)
	durationSeconds := int64Metadata(
		entity.Metadata,
		"harvest_duration_seconds",
		int64(definition.HarvestDuration/time.Second),
	)
	if durationSeconds <= 0 {
		return defaultHarvestDuration
	}
	return time.Duration(durationSeconds) * time.Second
}

func randomIndex(length int) int {
	if length <= 1 {
		return 0
	}
	return int(randomUnitFloat() * float64(length))
}

func forestCandidates(forest forestArea, minGap int) []domain.Point {
	step := minGap
	if step <= 0 {
		step = 1
	}

	width := (forest.MaxX-forest.MinX)/step + 1
	height := (forest.MaxY-forest.MinY)/step + 1
	candidates := make([]domain.Point, 0, width*height)
	for y := forest.MinY; y <= forest.MaxY; y += step {
		for x := forest.MinX; x <= forest.MaxX; x += step {
			candidates = append(candidates, domain.Point{X: x, Y: y})
		}
	}
	return candidates
}

func shufflePoints(points []domain.Point) {
	for index := len(points) - 1; index > 0; index-- {
		swapIndex := randomIndex(index + 1)
		points[index], points[swapIndex] = points[swapIndex], points[index]
	}
}

func canPlaceForestTree(candidate domain.Point, occupied []domain.Point, minGap int) bool {
	for _, point := range occupied {
		if !hasMinimumGap(candidate, point, minGap) {
			return false
		}
	}
	return true
}

func hasMinimumGap(a domain.Point, b domain.Point, minGap int) bool {
	if minGap <= 0 {
		return true
	}
	return absInt(a.X-b.X) >= minGap || absInt(a.Y-b.Y) >= minGap
}

func absInt(value int) int {
	if value < 0 {
		return -value
	}
	return value
}
