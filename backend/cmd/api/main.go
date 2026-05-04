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

	"starter/backend/internal/app"
	"starter/backend/internal/config"
	"starter/backend/internal/db"
	apphttp "starter/backend/internal/http"
	"starter/backend/internal/platform/logger"
	"starter/backend/internal/service"
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

	services := app.NewServices(pool, cfg)
	go services.Realtime.Run(ctx, log)
	if cfg.RunEmbeddedWorkers {
		actionWorker := service.NewActionWorker(services.Action, cfg.ActionWorkerInterval, cfg.ActionWorkerBatchSize, log)
		dispatcherWorker := service.NewEventDispatcherWorker(services.EventDispatcher, cfg.EventDispatcherInterval, cfg.EventDispatcherBatchSize, log)
		log.Info("embedded workers enabled", "action_interval", cfg.ActionWorkerInterval.String(), "event_interval", cfg.EventDispatcherInterval.String())
		go actionWorker.Run(ctx)
		go dispatcherWorker.Run(ctx)
	}

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           apphttp.NewRouter(cfg, logger.New(), services.Auth, services.State, services.Map, services.Entity, services.Player, services.Action, services.Event, services.Inventory, services.Admin, services.Realtime),
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
