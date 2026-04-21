package service

import (
	"context"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

type MapService struct {
	store store.MapStore
}

func NewMapService(store store.MapStore) *MapService {
	return &MapService{store: store}
}

func (s *MapService) Load(ctx context.Context, userID uuid.UUID) (domain.TileMap, error) {
	tileMap, err := s.store.GetTileMap(ctx, userID)
	if err != nil {
		return domain.TileMap{}, err
	}
	return s.store.SaveTileMap(ctx, normalizeTileMap(tileMap, userID))
}

func normalizeTileMap(tileMap domain.TileMap, userID uuid.UUID) domain.TileMap {
	template := store.DefaultTileMap(userID)
	width := template.Width
	height := template.Height
	tileSize := template.TileSize

	if tileMap.Width != width || tileMap.Height != height || len(tileMap.Tiles) != width*height {
		resized := append([]int(nil), template.Tiles...)
		copyWidth := minPositive(tileMap.Width, width)
		copyHeight := minPositive(tileMap.Height, height)
		for row := range copyHeight {
			for col := range copyWidth {
				sourceIndex := row*tileMap.Width + col
				targetIndex := row*width + col
				if sourceIndex >= 0 && sourceIndex < len(tileMap.Tiles) {
					if tileMap.Tiles[sourceIndex] > 0 {
						resized[targetIndex] = tileMap.Tiles[sourceIndex]
					}
				}
			}
		}
		tileMap.Tiles = resized
	} else if isSingleTilePlaceholder(tileMap.Tiles) {
		tileMap.Tiles = append([]int(nil), template.Tiles...)
	}
	for index, tileID := range tileMap.Tiles {
		if tileID <= 0 {
			tileMap.Tiles[index] = template.Tiles[index]
		}
	}
	tileMap.Width = width
	tileMap.Height = height
	tileMap.TileSize = tileSize
	tileMap.Tilesets = template.Tilesets
	tileMap.UserID = userID
	return tileMap
}

func isSingleTilePlaceholder(tiles []int) bool {
	if len(tiles) == 0 {
		return false
	}
	for _, tileID := range tiles {
		if tileID != 1 {
			return false
		}
	}
	return true
}

func minPositive(a, b int) int {
	if a <= 0 || b <= 0 {
		return 0
	}
	if a < b {
		return a
	}
	return b
}
