package service

import (
	"context"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"
)

const (
	eventDeliveryDestinationInbox = "inbox"
	eventDeliveryStatusPending    = "pending"
)

type EventDispatcher struct {
	transactor store.Transactor
	now        func() time.Time
}

func NewEventDispatcher(transactor store.Transactor) *EventDispatcher {
	return &EventDispatcher{
		transactor: transactor,
		now:        func() time.Time { return time.Now().UTC() },
	}
}

func (s *EventDispatcher) ProcessPending(ctx context.Context, limit int) (int, error) {
	if limit <= 0 {
		limit = 1
	}
	if s == nil || s.transactor == nil {
		return 0, nil
	}

	processed := 0
	for processed < limit {
		handled := false
		now := s.now()
		err := s.transactor.WithinTx(ctx, func(stores store.Stores) error {
			delivery, err := stores.EventOutbox.ClaimNextPendingDelivery(ctx, eventDeliveryDestinationInbox, now)
			if err != nil {
				return err
			}
			if delivery == nil {
				return nil
			}
			handled = true

			event, err := stores.Events.GetEvent(ctx, delivery.EventID)
			if err != nil {
				return err
			}
			_, err = stores.EventInbox.AppendInboxItems(ctx, []domain.PlayerInboxItem{{
				UserID:      delivery.UserID,
				EventID:     event.ID,
				Status:      "unread",
				DeliveredAt: now,
			}})
			if err != nil {
				return err
			}
			if err := stores.EventOutbox.MarkDeliveryDelivered(ctx, delivery.ID, now); err != nil {
				return err
			}
			return notifyRealtimeStores(ctx, stores, delivery.UserID, realtimeTopicEvents)
		})
		if err != nil {
			return processed, err
		}
		if !handled {
			break
		}
		processed++
	}
	return processed, nil
}
