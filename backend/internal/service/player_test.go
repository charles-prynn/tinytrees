package service

import (
	"math"
	"testing"

	"starter/backend/internal/domain"
)

func TestFastestPathUsesDiagonals(t *testing.T) {
	tileMap := domain.TileMap{
		Width:  8,
		Height: 8,
		Tiles:  filledTiles(8 * 8),
	}

	path := fastestPath(tileMap, nil, domain.Point{X: 0, Y: 0}, domain.Point{X: 3, Y: 2})

	if path[0] != (domain.Point{X: 0, Y: 0}) {
		t.Fatalf("expected path to start at 0,0, got %#v", path[0])
	}
	if path[len(path)-1] != (domain.Point{X: 3, Y: 2}) {
		t.Fatalf("expected path to end at 3,2, got %#v", path[len(path)-1])
	}
	for i := 0; i < len(path)-1; i++ {
		dx := math.Abs(float64(path[i].X - path[i+1].X))
		dy := math.Abs(float64(path[i].Y - path[i+1].Y))
		if dx > 1 || dy > 1 || dx+dy == 0 {
			t.Fatalf("path contains invalid step from %#v to %#v", path[i], path[i+1])
		}
	}

	expectedDistance := 2*math.Sqrt2 + 1
	if got := pathDistance(path); math.Abs(got-expectedDistance) > 0.0001 {
		t.Fatalf("expected distance %.4f, got %.4f", expectedDistance, got)
	}
}

func TestFastestPathAvoidsBlockedEntityTiles(t *testing.T) {
	tileMap := domain.TileMap{
		Width:  6,
		Height: 6,
		Tiles:  filledTiles(6 * 6),
	}
	blocked := blockedEntityTiles([]domain.Entity{
		{
			Type:   "resource",
			State:  "idle",
			X:      2,
			Y:      1,
			Width:  2,
			Height: 2,
		},
	})

	path := fastestPath(tileMap, blocked, domain.Point{X: 1, Y: 2}, domain.Point{X: 4, Y: 2})
	if len(path) <= 1 {
		t.Fatalf("expected path around resource, got %#v", path)
	}
	for _, point := range path {
		if _, isBlocked := blocked[point]; isBlocked {
			t.Fatalf("path walked through blocked resource tile %#v: %#v", point, path)
		}
	}
	if path[len(path)-1] != (domain.Point{X: 4, Y: 2}) {
		t.Fatalf("expected path to reach target, got %#v", path)
	}
}

func filledTiles(count int) []int {
	tiles := make([]int, count)
	for i := range tiles {
		tiles[i] = 1
	}
	return tiles
}
