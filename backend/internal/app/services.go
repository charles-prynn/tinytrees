package app

import (
	"starter/backend/internal/auth"
	"starter/backend/internal/config"
	"starter/backend/internal/service"
	"starter/backend/internal/store"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Services struct {
	Stores          store.Stores
	Transactor      store.Transactor
	Auth            *service.AuthService
	State           *service.StateService
	Map             *service.MapService
	Entity          *service.EntityService
	Player          *service.PlayerService
	Action          *service.ActionService
	Event           *service.EventService
	Inventory       *service.InventoryService
	Admin           *service.AdminService
	EventDispatcher *service.EventDispatcher
	Realtime        *service.RealtimeBroker
}

func NewServices(pool *pgxpool.Pool, cfg config.Config) Services {
	stores := store.NewPostgresStores(pool).Interfaces()
	transactor := store.NewPostgresTransactor(pool)
	realtime := service.NewRealtimeBroker(cfg.DatabaseURL)
	tokenManager := auth.NewTokenManager(cfg.AccessTokenSecret, cfg.RefreshTokenSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)

	authService := service.NewAuthService(stores.Users, stores.Sessions, tokenManager)
	stateService := service.NewStateService(stores.State)
	mapService := service.NewMapService(stores.Maps)
	entityService := service.NewEntityService(stores.Entities)
	playerService := service.NewPlayerService(stores.Players, stores.Maps, stores.Entities, stores.Skills)
	actionService := service.NewActionService(stores.Actions, stores.Inventory, stores.Skills, stores.Players, stores.Entities)
	actionService.SetTransactor(transactor)
	actionService.SetEventStore(stores.Events)
	actionService.SetEventOutboxStore(stores.EventOutbox)
	actionService.SetRealtimeStore(stores.Realtime)
	playerService.SetActionService(actionService)
	playerService.SetRealtimeStore(stores.Realtime)
	inventoryService := service.NewInventoryService(stores.Inventory, stores.Bank, stores.Players, stores.Entities, actionService)
	inventoryService.SetRealtimeStore(stores.Realtime)
	eventService := service.NewEventService(stores.EventInbox)
	eventService.SetRealtimeStore(stores.Realtime)
	adminService := service.NewAdminService(
		stores.Users,
		playerService,
		inventoryService,
		entityService,
		actionService,
		stores.Players,
		stores.Maps,
		stores.Entities,
		stores.Inventory,
		stores.Skills,
	)
	adminService.SetRealtimeStore(stores.Realtime)

	return Services{
		Stores:          stores,
		Transactor:      transactor,
		Auth:            authService,
		State:           stateService,
		Map:             mapService,
		Entity:          entityService,
		Player:          playerService,
		Action:          actionService,
		Event:           eventService,
		Inventory:       inventoryService,
		Admin:           adminService,
		EventDispatcher: service.NewEventDispatcher(transactor),
		Realtime:        realtime,
	}
}
