package store

import (
	"context"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

type UserStore interface {
	CreateGuest(ctx context.Context) (domain.User, error)
	GetByID(ctx context.Context, id uuid.UUID) (domain.User, error)
}

type SessionStore interface {
	Create(ctx context.Context, session domain.Session) (domain.Session, error)
	Get(ctx context.Context, id uuid.UUID) (domain.Session, error)
	UpdateRefreshHash(ctx context.Context, id uuid.UUID, refreshHash string, expiresAt time.Time) error
	Touch(ctx context.Context, id uuid.UUID) error
	Revoke(ctx context.Context, id uuid.UUID) error
}

type StateStore interface {
	GetSnapshot(ctx context.Context, userID uuid.UUID) (domain.StateSnapshot, error)
	SaveSnapshot(ctx context.Context, snapshot domain.StateSnapshot) (domain.StateSnapshot, error)
}

type MapStore interface {
	GetTileMap(ctx context.Context, userID uuid.UUID) (domain.TileMap, error)
	SaveTileMap(ctx context.Context, tileMap domain.TileMap) (domain.TileMap, error)
}

type EntityStore interface {
	ListEntities(ctx context.Context, userID uuid.UUID) ([]domain.Entity, error)
	CreateEntity(ctx context.Context, entity domain.Entity) (domain.Entity, error)
}

type PlayerStore interface {
	GetPlayer(ctx context.Context, userID uuid.UUID) (domain.Player, error)
	CreatePlayer(ctx context.Context, player domain.Player) (domain.Player, error)
	SavePlayer(ctx context.Context, player domain.Player) (domain.Player, error)
}

type Stores struct {
	Users    UserStore
	Sessions SessionStore
	State    StateStore
	Maps     MapStore
	Entities EntityStore
	Players  PlayerStore
}
