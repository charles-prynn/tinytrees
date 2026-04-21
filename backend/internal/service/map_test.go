package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestMapServiceNormalizesMissingMapFields(t *testing.T) {
	userID := uuid.New()
	service := NewMapService(&memoryMap{tileMap: domain.TileMap{UserID: userID}})

	tileMap, err := service.Load(context.Background(), userID)
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if tileMap.Width != 64 || tileMap.Height != 32 || tileMap.TileSize != 32 {
		t.Fatalf("unexpected normalized map dimensions: %+v", tileMap)
	}
	if len(tileMap.Tiles) != 64*32 {
		t.Fatalf("expected 2048 tiles, got %d", len(tileMap.Tiles))
	}
	expectedPrefix := []int{1, 2, 3, 4}
	for index, expected := range expectedPrefix {
		if tileMap.Tiles[index] != expected {
			t.Fatalf("expected tile %d to use Tiled gid %d, got %d", index, expected, tileMap.Tiles[index])
		}
	}
}

type memoryMap struct {
	tileMap domain.TileMap
}

func (m *memoryMap) GetTileMap(_ context.Context, userID uuid.UUID) (domain.TileMap, error) {
	m.tileMap.UserID = userID
	return m.tileMap, nil
}

func (m *memoryMap) SaveTileMap(_ context.Context, tileMap domain.TileMap) (domain.TileMap, error) {
	tileMap.UpdatedAt = time.Now().UTC()
	m.tileMap = tileMap
	return tileMap, nil
}
