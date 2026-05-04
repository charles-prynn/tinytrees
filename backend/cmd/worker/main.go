package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"starter/backend/internal/app"
	"starter/backend/internal/config"
	"starter/backend/internal/db"
	"starter/backend/internal/platform/logger"
	"starter/backend/internal/service"
)

func main() {
	log := logger.New()
	if err := run(log); err != nil {
		log.Error("worker stopped", "error", err)
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
	actionWorker := service.NewActionWorker(services.Action, cfg.ActionWorkerInterval, cfg.ActionWorkerBatchSize, log)
	dispatcherWorker := service.NewEventDispatcherWorker(services.EventDispatcher, cfg.EventDispatcherInterval, cfg.EventDispatcherBatchSize, log)

	log.Info("worker listening", "action_interval", cfg.ActionWorkerInterval.String(), "event_interval", cfg.EventDispatcherInterval.String())
	go actionWorker.Run(ctx)
	go dispatcherWorker.Run(ctx)

	<-ctx.Done()
	return nil
}
