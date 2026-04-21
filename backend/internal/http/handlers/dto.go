package handlers

import (
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/service"
)

type userDTO struct {
	ID          string    `json:"id"`
	Provider    string    `json:"provider"`
	DisplayName string    `json:"display_name"`
	CreatedAt   time.Time `json:"created_at"`
}

type tokenDTO struct {
	AccessToken           string    `json:"access_token"`
	RefreshToken          string    `json:"refresh_token"`
	AccessTokenExpiresAt  time.Time `json:"access_token_expires_at"`
	RefreshTokenExpiresAt time.Time `json:"refresh_token_expires_at"`
}

type authDTO struct {
	User   userDTO  `json:"user"`
	Tokens tokenDTO `json:"tokens"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type stateSyncRequest struct {
	Version  int64          `json:"version"`
	Metadata map[string]any `json:"metadata"`
}

type playerMoveRequest struct {
	TargetX int `json:"target_x"`
	TargetY int `json:"target_y"`
}

type tiledMapDTO struct {
	CompressionLevel int                `json:"compressionlevel"`
	Height           int                `json:"height"`
	Infinite         bool               `json:"infinite"`
	Layers           []tiledLayerDTO    `json:"layers"`
	NextLayerID      int                `json:"nextlayerid"`
	NextObjectID     int                `json:"nextobjectid"`
	Orientation      string             `json:"orientation"`
	Properties       []tiledPropertyDTO `json:"properties,omitempty"`
	RenderOrder      string             `json:"renderorder"`
	TiledVersion     string             `json:"tiledversion"`
	TileHeight       int                `json:"tileheight"`
	Tilesets         []tiledTilesetDTO  `json:"tilesets"`
	TileWidth        int                `json:"tilewidth"`
	Type             string             `json:"type"`
	Version          string             `json:"version"`
	Width            int                `json:"width"`
}

type tiledLayerDTO struct {
	Data    []int   `json:"data"`
	Height  int     `json:"height"`
	ID      int     `json:"id"`
	Name    string  `json:"name"`
	Opacity float64 `json:"opacity"`
	Type    string  `json:"type"`
	Visible bool    `json:"visible"`
	Width   int     `json:"width"`
	X       int     `json:"x"`
	Y       int     `json:"y"`
}

type tiledTilesetDTO struct {
	Columns     int    `json:"columns"`
	FirstGID    int    `json:"firstgid"`
	Image       string `json:"image"`
	ImageWidth  int    `json:"imagewidth"`
	ImageHeight int    `json:"imageheight"`
	Margin      int    `json:"margin"`
	Name        string `json:"name"`
	Spacing     int    `json:"spacing"`
	TileCount   int    `json:"tilecount"`
	TileHeight  int    `json:"tileheight"`
	TileWidth   int    `json:"tilewidth"`
}

type tiledPropertyDTO struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Value any    `json:"value"`
}

type entityDTO struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Type        string         `json:"type"`
	ResourceKey string         `json:"resource_key,omitempty"`
	X           int            `json:"x"`
	Y           int            `json:"y"`
	Width       int            `json:"width"`
	Height      int            `json:"height"`
	SpriteGID   int            `json:"sprite_gid"`
	State       string         `json:"state"`
	Metadata    map[string]any `json:"metadata"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

type pointDTO struct {
	X int `json:"x"`
	Y int `json:"y"`
}

type playerMovementDTO struct {
	FromX               int        `json:"from_x"`
	FromY               int        `json:"from_y"`
	TargetX             int        `json:"target_x"`
	TargetY             int        `json:"target_y"`
	Path                []pointDTO `json:"path"`
	StartedAt           time.Time  `json:"started_at"`
	ArrivesAt           time.Time  `json:"arrives_at"`
	SpeedTilesPerSecond float64    `json:"speed_tiles_per_second"`
}

type playerDTO struct {
	UserID    string             `json:"user_id"`
	X         int                `json:"x"`
	Y         int                `json:"y"`
	Movement  *playerMovementDTO `json:"movement,omitempty"`
	UpdatedAt time.Time          `json:"updated_at"`
}

func toUserDTO(user domain.User) userDTO {
	return userDTO{
		ID:          user.ID.String(),
		Provider:    user.Provider,
		DisplayName: user.DisplayName,
		CreatedAt:   user.CreatedAt,
	}
}

func toTokenDTO(tokens service.AuthTokens) tokenDTO {
	return tokenDTO{
		AccessToken:           tokens.AccessToken,
		RefreshToken:          tokens.RefreshToken,
		AccessTokenExpiresAt:  tokens.AccessTokenExpiresAt,
		RefreshTokenExpiresAt: tokens.RefreshTokenExpiresAt,
	}
}

func toAuthDTO(result service.AuthResult) authDTO {
	return authDTO{User: toUserDTO(result.User), Tokens: toTokenDTO(result.Tokens)}
}

func toTiledMapDTO(tileMap domain.TileMap) tiledMapDTO {
	tiles := make([]int, len(tileMap.Tiles))
	copy(tiles, tileMap.Tiles)

	return tiledMapDTO{
		CompressionLevel: -1,
		Height:           tileMap.Height,
		Infinite:         false,
		Layers: []tiledLayerDTO{
			{
				Data:    tiles,
				Height:  tileMap.Height,
				ID:      1,
				Name:    "Ground",
				Opacity: 1,
				Type:    "tilelayer",
				Visible: true,
				Width:   tileMap.Width,
				X:       0,
				Y:       0,
			},
		},
		NextLayerID:  2,
		NextObjectID: 1,
		Orientation:  "orthogonal",
		Properties: []tiledPropertyDTO{
			{Name: "user_id", Type: "string", Value: tileMap.UserID.String()},
			{Name: "updated_at", Type: "string", Value: tileMap.UpdatedAt.Format(time.RFC3339Nano)},
		},
		RenderOrder:  "right-down",
		TiledVersion: "1.11.2",
		TileHeight:   tileMap.TileSize,
		Tilesets:     toTiledTilesetDTOs(tileMap),
		TileWidth:    tileMap.TileSize,
		Type:         "map",
		Version:      "1.10",
		Width:        tileMap.Width,
	}
}

func toTiledTilesetDTOs(tileMap domain.TileMap) []tiledTilesetDTO {
	if len(tileMap.Tilesets) == 0 {
		return []tiledTilesetDTO{
			{
				Columns:     8,
				FirstGID:    1,
				Image:       "tiles/tile_map.png",
				ImageWidth:  256,
				ImageHeight: 256,
				Name:        "tile_map",
				TileCount:   64,
				TileHeight:  tileMap.TileSize,
				TileWidth:   tileMap.TileSize,
			},
		}
	}

	tilesets := make([]tiledTilesetDTO, 0, len(tileMap.Tilesets))
	for _, tileset := range tileMap.Tilesets {
		tilesets = append(tilesets, tiledTilesetDTO{
			Columns:     tileset.Columns,
			FirstGID:    tileset.FirstGID,
			Image:       tileset.Image,
			ImageWidth:  tileset.ImageWidth,
			ImageHeight: tileset.ImageHeight,
			Margin:      tileset.Margin,
			Name:        tileset.Name,
			Spacing:     tileset.Spacing,
			TileCount:   tileset.TileCount,
			TileHeight:  tileset.TileHeight,
			TileWidth:   tileset.TileWidth,
		})
	}
	return tilesets
}

func toEntityDTOs(entities []domain.Entity) []entityDTO {
	items := make([]entityDTO, 0, len(entities))
	for _, entity := range entities {
		items = append(items, entityDTO{
			ID:          entity.ID.String(),
			Name:        entity.Name,
			Type:        entity.Type,
			ResourceKey: entity.ResourceKey,
			X:           entity.X,
			Y:           entity.Y,
			Width:       entity.Width,
			Height:      entity.Height,
			SpriteGID:   entity.SpriteGID,
			State:       entity.State,
			Metadata:    entity.Metadata,
			UpdatedAt:   entity.UpdatedAt,
		})
	}
	return items
}

func toPlayerDTO(player domain.Player) playerDTO {
	return playerDTO{
		UserID:    player.UserID.String(),
		X:         player.X,
		Y:         player.Y,
		Movement:  toPlayerMovementDTO(player.Movement),
		UpdatedAt: player.UpdatedAt,
	}
}

func toPlayerMovementDTO(movement *domain.PlayerMovement) *playerMovementDTO {
	if movement == nil {
		return nil
	}

	path := make([]pointDTO, 0, len(movement.Path))
	for _, point := range movement.Path {
		path = append(path, pointDTO{X: point.X, Y: point.Y})
	}

	return &playerMovementDTO{
		FromX:               movement.FromX,
		FromY:               movement.FromY,
		TargetX:             movement.TargetX,
		TargetY:             movement.TargetY,
		Path:                path,
		StartedAt:           movement.StartedAt,
		ArrivesAt:           movement.ArrivesAt,
		SpeedTilesPerSecond: movement.SpeedTilesPerSecond,
	}
}
