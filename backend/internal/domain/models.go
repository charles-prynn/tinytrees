package domain

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID          uuid.UUID
	Provider    string
	DisplayName string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Session struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	RefreshHash string
	ExpiresAt   time.Time
	RevokedAt   *time.Time
	CreatedAt   time.Time
	LastUsedAt  time.Time
}

type Wallet struct {
	UserID    uuid.UUID
	Balances  map[string]int64
	UpdatedAt time.Time
}

type Resource struct {
	ID        uuid.UUID
	Key       string
	Quantity  int64
	Metadata  map[string]any
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Assignment struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Key       string
	Status    string
	Metadata  map[string]any
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Item struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Key       string
	Metadata  map[string]any
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Upgrade struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Key       string
	Level     int
	Metadata  map[string]any
	CreatedAt time.Time
	UpdatedAt time.Time
}

type StateSnapshot struct {
	UserID      uuid.UUID
	Version     int64
	Resources   []Resource
	Assignments []Assignment
	Items       []Item
	Upgrades    []Upgrade
	Metadata    map[string]any
	UpdatedAt   time.Time
}

const (
	DefaultTileMapWidth    = 64
	DefaultTileMapHeight   = 32
	DefaultTileMapTileSize = 32
)

type TileMap struct {
	UserID    uuid.UUID `json:"user_id"`
	Width     int       `json:"width"`
	Height    int       `json:"height"`
	TileSize  int       `json:"tile_size"`
	Tiles     []int     `json:"tiles"`
	Tilesets  []Tileset `json:"tilesets,omitempty"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Tileset struct {
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

type Entity struct {
	ID          uuid.UUID      `json:"id"`
	UserID      uuid.UUID      `json:"user_id"`
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
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

type Point struct {
	X int `json:"x"`
	Y int `json:"y"`
}

type PlayerMovement struct {
	FromX               int       `json:"from_x"`
	FromY               int       `json:"from_y"`
	TargetX             int       `json:"target_x"`
	TargetY             int       `json:"target_y"`
	Path                []Point   `json:"path"`
	StartedAt           time.Time `json:"started_at"`
	ArrivesAt           time.Time `json:"arrives_at"`
	SpeedTilesPerSecond float64   `json:"speed_tiles_per_second"`
}

type Player struct {
	UserID    uuid.UUID       `json:"user_id"`
	X         int             `json:"x"`
	Y         int             `json:"y"`
	Movement  *PlayerMovement `json:"movement,omitempty"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}
