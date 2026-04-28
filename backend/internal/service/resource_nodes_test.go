package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestEnsureResourceNodesPlacesTreesInsideAssignedForests(t *testing.T) {
	userID := uuid.New()
	store := &memoryEntities{}

	entities, err := ensureResourceNodes(context.Background(), store, userID, time.Now().UTC())
	if err != nil {
		t.Fatalf("ensureResourceNodes returned error: %v", err)
	}
	if len(entities) != resourceNodeTargetCount {
		t.Fatalf("expected %d resource nodes, got %d", resourceNodeTargetCount, len(entities))
	}

	counts := map[string]int{}
	expectedCounts := scaledTreeTargetCounts(resourceNodeTargetCount)
	for _, entity := range entities {
		forest, ok := treeForestAreas[entity.ResourceKey]
		if !ok {
			t.Fatalf("missing forest definition for %q", entity.ResourceKey)
		}
		if entity.X < forest.MinX || entity.X > forest.MaxX || entity.Y < forest.MinY || entity.Y > forest.MaxY {
			t.Fatalf("entity %+v spawned outside forest bounds %+v", entity, forest)
		}
		counts[entity.ResourceKey]++
	}

	for key, expected := range expectedCounts {
		if counts[key] != expected {
			t.Fatalf("expected %d %s nodes, got %d", expected, key, counts[key])
		}
	}
}

func TestEnsureResourceNodesKeepsTreesSpacedApart(t *testing.T) {
	userID := uuid.New()
	store := &memoryEntities{}

	entities, err := ensureResourceNodes(context.Background(), store, userID, time.Now().UTC())
	if err != nil {
		t.Fatalf("ensureResourceNodes returned error: %v", err)
	}

	for i := 0; i < len(entities); i++ {
		for j := i + 1; j < len(entities); j++ {
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
