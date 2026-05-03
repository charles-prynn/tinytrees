package service

import (
	"context"
	"time"
)

const defaultActionWorkerBatchSize = 32

type ActionWorker struct {
	actions   *ActionService
	interval  time.Duration
	batchSize int
	log       interface {
		Info(string, ...any)
		Error(string, ...any)
	}
}

func NewActionWorker(actions *ActionService, interval time.Duration, batchSize int, log interface {
	Info(string, ...any)
	Error(string, ...any)
}) *ActionWorker {
	if interval <= 0 {
		interval = 500 * time.Millisecond
	}
	if batchSize <= 0 {
		batchSize = defaultActionWorkerBatchSize
	}
	return &ActionWorker{
		actions:   actions,
		interval:  interval,
		batchSize: batchSize,
		log:       log,
	}
}

func (w *ActionWorker) Run(ctx context.Context) {
	if w == nil || w.actions == nil {
		return
	}

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		processed, err := w.actions.ProcessDue(ctx, w.batchSize)
		if err != nil && w.log != nil {
			w.log.Error("action worker iteration failed", "error", err)
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
