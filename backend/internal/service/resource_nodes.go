package service

import (
	"context"
	"time"

	"starter/backend/internal/domain"
	storepkg "starter/backend/internal/store"

	"github.com/google/uuid"
)

const (
	resourceStateIdle             = "idle"
	resourceStateDepleted         = "depleted"
	bankEntityType                = "bank"
	bankEntityResourceKey         = "bank_chest"
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

type forestCluster struct {
	CenterX int
	CenterY int
	RadiusX int
	RadiusY int
}

type forestClusterSeed struct {
	CenterXRatio float64
	CenterYRatio float64
	RadiusXRatio float64
	RadiusYRatio float64
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

	treeForestClusterSeeds = map[string][]forestClusterSeed{
		"tree": {
			{CenterXRatio: 0.12, CenterYRatio: 0.14, RadiusXRatio: 0.12, RadiusYRatio: 0.10},
			{CenterXRatio: 0.26, CenterYRatio: 0.36, RadiusXRatio: 0.13, RadiusYRatio: 0.11},
			{CenterXRatio: 0.44, CenterYRatio: 0.18, RadiusXRatio: 0.12, RadiusYRatio: 0.10},
			{CenterXRatio: 0.63, CenterYRatio: 0.52, RadiusXRatio: 0.12, RadiusYRatio: 0.10},
			{CenterXRatio: 0.80, CenterYRatio: 0.28, RadiusXRatio: 0.11, RadiusYRatio: 0.09},
		},
		"oak_tree": {
			{CenterXRatio: 0.22, CenterYRatio: 0.16, RadiusXRatio: 0.10, RadiusYRatio: 0.08},
			{CenterXRatio: 0.48, CenterYRatio: 0.58, RadiusXRatio: 0.10, RadiusYRatio: 0.08},
			{CenterXRatio: 0.74, CenterYRatio: 0.22, RadiusXRatio: 0.10, RadiusYRatio: 0.08},
			{CenterXRatio: 0.86, CenterYRatio: 0.70, RadiusXRatio: 0.09, RadiusYRatio: 0.07},
		},
		"willow_tree": {
			{CenterXRatio: 0.36, CenterYRatio: 0.76, RadiusXRatio: 0.10, RadiusYRatio: 0.08},
			{CenterXRatio: 0.62, CenterYRatio: 0.14, RadiusXRatio: 0.10, RadiusYRatio: 0.08},
			{CenterXRatio: 0.82, CenterYRatio: 0.56, RadiusXRatio: 0.10, RadiusYRatio: 0.08},
			{CenterXRatio: 0.16, CenterYRatio: 0.66, RadiusXRatio: 0.09, RadiusYRatio: 0.07},
		},
		"maple_tree": {
			{CenterXRatio: 0.10, CenterYRatio: 0.78, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
			{CenterXRatio: 0.30, CenterYRatio: 0.56, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
			{CenterXRatio: 0.54, CenterYRatio: 0.30, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
			{CenterXRatio: 0.72, CenterYRatio: 0.82, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
		},
		"yew_tree": {
			{CenterXRatio: 0.22, CenterYRatio: 0.84, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
			{CenterXRatio: 0.52, CenterYRatio: 0.44, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
			{CenterXRatio: 0.76, CenterYRatio: 0.22, RadiusXRatio: 0.08, RadiusYRatio: 0.07},
			{CenterXRatio: 0.88, CenterYRatio: 0.86, RadiusXRatio: 0.07, RadiusYRatio: 0.06},
		},
		"magic_tree": {
			{CenterXRatio: 0.14, CenterYRatio: 0.26, RadiusXRatio: 0.07, RadiusYRatio: 0.06},
			{CenterXRatio: 0.40, CenterYRatio: 0.90, RadiusXRatio: 0.07, RadiusYRatio: 0.06},
			{CenterXRatio: 0.68, CenterYRatio: 0.68, RadiusXRatio: 0.07, RadiusYRatio: 0.06},
			{CenterXRatio: 0.92, CenterYRatio: 0.38, RadiusXRatio: 0.07, RadiusYRatio: 0.06},
		},
	}
	treeDefinitionByKey = map[string]treeDefinition{}
)

func init() {
	for _, definition := range treeDefinitions {
		treeDefinitionByKey[definition.Key] = definition
	}
}

func ensureResourceNodes(ctx context.Context, entityStore storepkg.EntityStore, userID uuid.UUID, now time.Time) ([]domain.Entity, error) {
	tileMap := storepkg.DefaultTileMap(userID)
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

	if bankEntity, ok := ensureBankEntity(userID, filtered); ok {
		created, err := entityStore.CreateEntity(ctx, bankEntity)
		if err != nil {
			return nil, err
		}
		filtered = append(filtered, created)
		changed = true
	}

	missing := missingTreeTypes(filtered)
	for _, resourceKey := range missing {
		entity, ok := spawnResourceEntity(userID, filtered, resourceKey, tileMap.Width, tileMap.Height)
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

func ensureBankEntity(userID uuid.UUID, entities []domain.Entity) (domain.Entity, bool) {
	for _, entity := range entities {
		if entity.Type == bankEntityType {
			return domain.Entity{}, false
		}
	}

	return domain.Entity{
		ID:          uuid.New(),
		UserID:      userID,
		Name:        "Bank",
		Type:        bankEntityType,
		ResourceKey: bankEntityResourceKey,
		X:           18,
		Y:           8,
		Width:       1,
		Height:      1,
		SpriteGID:   1,
		State:       resourceStateIdle,
		Metadata:    map[string]any{},
	}, true
}

func depleteResourceNode(ctx context.Context, entityStore storepkg.EntityStore, entity domain.Entity, now time.Time) (domain.Entity, error) {
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

func spawnResourceEntity(userID uuid.UUID, entities []domain.Entity, resourceKey string, mapWidth int, mapHeight int) (domain.Entity, bool) {
	definition, ok := treeDefinitionByKey[resourceKey]
	if !ok {
		definition = treeDefinitions[0]
	}
	clusters, ok := forestClustersForMap(definition.Key, mapWidth, mapHeight)
	if !ok {
		return domain.Entity{}, false
	}

	occupied := make([]domain.Point, 0, len(entities))
	for _, entity := range entities {
		occupied = append(occupied, domain.Point{X: entity.X, Y: entity.Y})
	}

	candidates := forestCandidates(clusters, minForestTreeGapTiles, mapWidth, mapHeight)
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

func forestCandidates(clusters []forestCluster, minGap int, mapWidth int, mapHeight int) []domain.Point {
	step := minGap
	if step <= 0 {
		step = 1
	}

	if len(clusters) == 0 {
		return nil
	}

	seen := map[domain.Point]struct{}{}
	candidates := make([]domain.Point, 0)
	for _, cluster := range clusters {
		minY := maxInt(0, cluster.CenterY-cluster.RadiusY)
		maxY := minInt(mapHeight-1, cluster.CenterY+cluster.RadiusY)
		minX := maxInt(0, cluster.CenterX-cluster.RadiusX)
		maxX := minInt(mapWidth-1, cluster.CenterX+cluster.RadiusX)

		for y := minY; y <= maxY; y += step {
			rowOffset := ((y - minY) / step) % 2
			xOffset := rowOffset * maxInt(1, step/2)
			for x := minX + xOffset; x <= maxX; x += step {
				point := domain.Point{X: x, Y: y}
				if !pointInForestClusters(point, clusters) {
					continue
				}
				if _, ok := seen[point]; ok {
					continue
				}
				seen[point] = struct{}{}
				candidates = append(candidates, point)
			}
		}
	}
	return candidates
}

func forestClustersForMap(resourceKey string, mapWidth int, mapHeight int) ([]forestCluster, bool) {
	seeds, ok := treeForestClusterSeeds[resourceKey]
	if !ok {
		return nil, false
	}
	if mapWidth <= 0 {
		mapWidth = domain.DefaultTileMapWidth
	}
	if mapHeight <= 0 {
		mapHeight = domain.DefaultTileMapHeight
	}

	clusters := make([]forestCluster, 0, len(seeds))
	maxX := maxInt(0, mapWidth-1)
	maxY := maxInt(0, mapHeight-1)
	for _, seed := range seeds {
		cluster := forestCluster{
			CenterX: clampInt(int(seed.CenterXRatio*float64(maxX)), 0, maxX),
			CenterY: clampInt(int(seed.CenterYRatio*float64(maxY)), 0, maxY),
			RadiusX: maxInt(minForestTreeGapTiles, int(seed.RadiusXRatio*float64(mapWidth))),
			RadiusY: maxInt(minForestTreeGapTiles, int(seed.RadiusYRatio*float64(mapHeight))),
		}
		clusters = append(clusters, cluster)
	}
	return clusters, true
}

func pointInForestClusters(point domain.Point, clusters []forestCluster) bool {
	for _, cluster := range clusters {
		if pointInForestCluster(point, cluster) {
			return true
		}
	}
	return false
}

func pointInForestCluster(point domain.Point, cluster forestCluster) bool {
	if cluster.RadiusX <= 0 || cluster.RadiusY <= 0 {
		return false
	}
	dx := float64(point.X-cluster.CenterX) / float64(cluster.RadiusX)
	dy := float64(point.Y-cluster.CenterY) / float64(cluster.RadiusY)
	return dx*dx+dy*dy <= 1
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

func minInt(a int, b int) int {
	if a < b {
		return a
	}
	return b
}

func maxInt(a int, b int) int {
	if a > b {
		return a
	}
	return b
}

func clampInt(value int, minValue int, maxValue int) int {
	if value < minValue {
		return minValue
	}
	if value > maxValue {
		return maxValue
	}
	return value
}
