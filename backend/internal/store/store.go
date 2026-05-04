package store

import (
	"context"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

type UserStore interface {
	CreateGuest(ctx context.Context) (domain.User, error)
	GetByEmail(ctx context.Context, email string) (domain.User, error)
	GetByUsername(ctx context.Context, username string) (domain.User, error)
	GetByID(ctx context.Context, id uuid.UUID) (domain.User, error)
	ListUsers(ctx context.Context) ([]domain.User, error)
	GetPasswordHash(ctx context.Context, id uuid.UUID) (string, error)
	UpgradeGuest(ctx context.Context, id uuid.UUID, username string, email *string, passwordHash string, displayName string) (domain.User, error)
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
	SaveEntity(ctx context.Context, entity domain.Entity) (domain.Entity, error)
	DeleteEntity(ctx context.Context, userID uuid.UUID, entityID uuid.UUID) error
}

type PlayerStore interface {
	GetPlayer(ctx context.Context, userID uuid.UUID) (domain.Player, error)
	CreatePlayer(ctx context.Context, player domain.Player) (domain.Player, error)
	SavePlayer(ctx context.Context, player domain.Player) (domain.Player, error)
}

type InventoryStore interface {
	ListInventory(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error)
	AddInventoryItem(ctx context.Context, userID uuid.UUID, itemKey string, quantity int64) (int64, error)
}

type BankStore interface {
	ListBank(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error)
	DepositInventoryItem(ctx context.Context, userID uuid.UUID, itemKey string, quantity int64) (int64, error)
}

type SkillStore interface {
	ListSkills(ctx context.Context, userID uuid.UUID) ([]domain.PlayerSkill, error)
	AddXP(ctx context.Context, userID uuid.UUID, skillKey string, xp int64) (domain.PlayerSkill, error)
}

type ActionStore interface {
	GetActiveAction(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error)
	CreateAction(ctx context.Context, action domain.PlayerAction) (domain.PlayerAction, error)
	SaveAction(ctx context.Context, action domain.PlayerAction) (domain.PlayerAction, error)
	ClaimNextDueAction(ctx context.Context, now time.Time) (*domain.PlayerAction, error)
}

type EventStore interface {
	GetEvent(ctx context.Context, eventID int64) (domain.PlayerEvent, error)
	AppendEvents(ctx context.Context, events []domain.PlayerEvent) ([]domain.PlayerEvent, error)
}

type EventOutboxStore interface {
	EnqueueDeliveries(ctx context.Context, deliveries []domain.PlayerEventDelivery) ([]domain.PlayerEventDelivery, error)
	ClaimNextPendingDelivery(ctx context.Context, destination string, now time.Time) (*domain.PlayerEventDelivery, error)
	MarkDeliveryDelivered(ctx context.Context, deliveryID int64, deliveredAt time.Time) error
}

type EventInboxStore interface {
	ListInbox(ctx context.Context, userID uuid.UUID, afterID int64, limit int) ([]domain.PlayerInboxItem, error)
	AppendInboxItems(ctx context.Context, items []domain.PlayerInboxItem) ([]domain.PlayerInboxItem, error)
	MarkInboxItemsRead(ctx context.Context, userID uuid.UUID, ids []int64, readAt time.Time) ([]domain.PlayerInboxItem, error)
}

type RealtimeNotification struct {
	UserID uuid.UUID
	Topics []string
}

type RealtimeStore interface {
	PublishRealtime(ctx context.Context, notification RealtimeNotification) error
}

type Transactor interface {
	WithinTx(ctx context.Context, fn func(Stores) error) error
}

type Stores struct {
	Users       UserStore
	Sessions    SessionStore
	State       StateStore
	Maps        MapStore
	Entities    EntityStore
	Players     PlayerStore
	Inventory   InventoryStore
	Bank        BankStore
	Skills      SkillStore
	Actions     ActionStore
	Events      EventStore
	EventOutbox EventOutboxStore
	EventInbox  EventInboxStore
	Realtime    RealtimeStore
}
