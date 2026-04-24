package http

import (
	"log/slog"
	"net"
	"net/http"
	"net/url"

	"starter/backend/internal/config"
	"starter/backend/internal/http/handlers"
	appmiddleware "starter/backend/internal/http/middleware"
	"starter/backend/internal/service"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

func NewRouter(cfg config.Config, log *slog.Logger, authService *service.AuthService, stateService *service.StateService, mapService *service.MapService, entityService *service.EntityService, playerService *service.PlayerService, actionService *service.ActionService, inventoryService *service.InventoryService) http.Handler {
	h := handlers.New(authService, stateService, mapService, entityService, playerService, actionService, inventoryService)
	r := chi.NewRouter()

	r.Use(chimiddleware.RequestID)
	r.Use(chimiddleware.RealIP)
	r.Use(appmiddleware.RequestLogging(log))
	r.Use(chimiddleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: true,
		AllowOriginFunc:  allowOrigin(cfg.AllowedOrigins),
		MaxAge:           300,
	}))

	r.Get("/health", h.Health)

	r.Route("/v1", func(r chi.Router) {
		r.Post("/auth/guest/login", h.GuestLogin)
		r.Post("/auth/refresh", h.Refresh)

		r.Group(func(r chi.Router) {
			r.Use(appmiddleware.Auth(authService))
			r.Post("/auth/logout", h.Logout)
			r.Get("/me", h.Me)
			r.Get("/ws", h.WebSocket)
			r.Get("/bootstrap", h.Bootstrap)
			r.Get("/state", h.GetState)
			r.Post("/state/sync", h.SyncState)
			r.Get("/map", h.GetMap)
			r.Get("/entities", h.GetEntities)
			r.Get("/player", h.GetPlayer)
			r.Post("/player/move", h.MovePlayer)
			r.Get("/actions/current", h.CurrentAction)
			r.Post("/actions/harvest", h.StartHarvest)
			r.Get("/inventory", h.GetInventory)
		})
	})

	return r
}

func allowOrigin(allowedOrigins []string) func(r *http.Request, origin string) bool {
	allowed := make(map[string]struct{}, len(allowedOrigins))
	allowLocalhostPorts := false
	for _, origin := range allowedOrigins {
		allowed[origin] = struct{}{}
		if isLoopbackOrigin(origin) {
			allowLocalhostPorts = true
		}
	}

	return func(_ *http.Request, origin string) bool {
		if _, ok := allowed[origin]; ok {
			return true
		}

		return allowLocalhostPorts && isLoopbackOrigin(origin)
	}
}

func isLoopbackOrigin(origin string) bool {
	parsed, err := url.Parse(origin)
	if err != nil {
		return false
	}

	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return false
	}

	host := parsed.Hostname()
	if host == "localhost" {
		return true
	}

	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
