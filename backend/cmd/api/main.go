package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"starter/backend/internal/auth"
	"starter/backend/internal/config"
	"starter/backend/internal/db"
	apphttp "starter/backend/internal/http"
	"starter/backend/internal/platform/logger"
	"starter/backend/internal/service"
	"starter/backend/internal/store"
)

func main() {
	log := logger.New()
	if err := run(log); err != nil {
		log.Error("api stopped", "error", err)
		os.Exit(1)
	}
}

func run(log interface {
	Info(string, ...any)
	Error(string, ...any)
}) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	stores := store.NewPostgresStores(pool).Interfaces()
	tokenManager := auth.NewTokenManager(cfg.AccessTokenSecret, cfg.RefreshTokenSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	authService := service.NewAuthService(stores.Users, stores.Sessions, tokenManager)
	stateService := service.NewStateService(stores.State)
	mapService := service.NewMapService(stores.Maps)
	entityService := service.NewEntityService(stores.Entities)
	playerService := service.NewPlayerService(stores.Players, stores.Maps, stores.Entities)

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           apphttp.NewRouter(cfg, logger.New(), authService, stateService, mapService, entityService, playerService),
		ReadHeaderTimeout: 5 * time.Second,
	}

	errs := make(chan error, 1)
	go func() {
		log.Info("api listening", "addr", server.Addr)
		errs <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			return err
		}
		return nil
	case err := <-errs:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
