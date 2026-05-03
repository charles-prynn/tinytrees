package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"
	storepkg "starter/backend/internal/store"

	"github.com/google/uuid"
)

func TestEnsureResourceNodesPlacesTreesInsideAssignedForests(t *testing.T) {
	userID := uuid.New()
	entityStore := &memoryEntities{}

	entities, err := ensureResourceNodes(context.Background(), entityStore, userID, time.Now().UTC())
	if err != nil {
		t.Fatalf("ensureResourceNodes returned error: %v", err)
	}

	counts := map[string]int{}
	expectedCounts := scaledTreeTargetCounts(resourceNodeTargetCount)
	tileMap := storepkg.DefaultTileMap(userID)
	bankCount := 0
	for _, entity := range entities {
		if entity.Type == bankEntityType {
			bankCount++
			continue
		}
		clusters, ok := forestClustersForMap(entity.ResourceKey, tileMap.Width, tileMap.Height)
		if !ok {
			t.Fatalf("missing forest clusters for %q", entity.ResourceKey)
		}
		if !pointInForestClusters(domain.Point{X: entity.X, Y: entity.Y}, clusters) {
			t.Fatalf("entity %+v spawned outside forest clusters %+v", entity, clusters)
		}
		counts[entity.ResourceKey]++
	}
	if bankCount != 1 {
		t.Fatalf("expected 1 bank entity, got %d", bankCount)
	}

	for key, expected := range expectedCounts {
		if counts[key] != expected {
			t.Fatalf("expected %d %s nodes, got %d", expected, key, counts[key])
		}
	}
}

func TestEnsureResourceNodesKeepsTreesSpacedApart(t *testing.T) {
	userID := uuid.New()
	entityStore := &memoryEntities{}

	entities, err := ensureResourceNodes(context.Background(), entityStore, userID, time.Now().UTC())
	if err != nil {
		t.Fatalf("ensureResourceNodes returned error: %v", err)
	}

	for i := 0; i < len(entities); i++ {
		if entities[i].Type == bankEntityType {
			continue
		}
		for j := i + 1; j < len(entities); j++ {
			if entities[j].Type == bankEntityType {
				continue
			}
			first := domain.Point{X: entities[i].X, Y: entities[i].Y}
			second := domain.Point{X: entities[j].X, Y: entities[j].Y}
			if !hasMinimumGap(first, second, minForestTreeGapTiles) {
				t.Fatalf("trees spawned too close together: %+v and %+v", entities[i], entities[j])
			}
		}
	}
}

func TestScaledTreeTargetCountsMatchesRequestedTotal(t *testing.T) {
	counts := scaledTreeTargetCounts(100)

	total := 0
	for _, count := range counts {
		total += count
	}
	if total != 100 {
		t.Fatalf("expected total target count of 100, got %d", total)
	}

	expected := map[string]int{
		"tree":        30,
		"oak_tree":    20,
		"willow_tree": 20,
		"maple_tree":  10,
		"yew_tree":    10,
		"magic_tree":  10,
	}
	for key, want := range expected {
		if counts[key] != want {
			t.Fatalf("expected %s count %d, got %d", key, want, counts[key])
		}
	}
}
