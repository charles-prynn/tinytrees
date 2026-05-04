package service

import (
	"context"
	"time"
)

const defaultEventDispatcherBatchSize = 64

type EventDispatcherWorker struct {
	dispatcher *EventDispatcher
	interval   time.Duration
	batchSize  int
	log        interface {
		Info(string, ...any)
		Error(string, ...any)
	}
}

func NewEventDispatcherWorker(dispatcher *EventDispatcher, interval time.Duration, batchSize int, log interface {
	Info(string, ...any)
	Error(string, ...any)
}) *EventDispatcherWorker {
	if interval <= 0 {
		interval = 500 * time.Millisecond
	}
	if batchSize <= 0 {
		batchSize = defaultEventDispatcherBatchSize
	}
	return &EventDispatcherWorker{
		dispatcher: dispatcher,
		interval:   interval,
		batchSize:  batchSize,
		log:        log,
	}
}

func (w *EventDispatcherWorker) Run(ctx context.Context) {
	if w == nil || w.dispatcher == nil {
		return
	}

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		processed, err := w.dispatcher.ProcessPending(ctx, w.batchSize)
		if err != nil && w.log != nil {
			w.log.Error("event dispatcher iteration failed", "error", err)
		}
		if processed >= w.batchSize {
			continue
		}

		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}
