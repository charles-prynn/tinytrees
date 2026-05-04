package service

import (
	"testing"
	"time"

	"starter/backend/internal/store"

	"github.com/google/uuid"
)

func TestRealtimeBrokerDispatchesOnlyToMatchingUser(t *testing.T) {
	broker := NewRealtimeBroker("")
	userID := uuid.New()
	otherUserID := uuid.New()

	updates, unsubscribe := broker.Subscribe(userID)
	defer unsubscribe()

	broker.dispatch(store.RealtimeNotification{
		UserID: otherUserID,
		Topics: []string{realtimeTopicPlayer},
	})

	select {
	case notification := <-updates:
		t.Fatalf("unexpected notification for another user: %+v", notification)
	case <-time.After(50 * time.Millisecond):
	}

	broker.dispatch(store.RealtimeNotification{
		UserID: userID,
		Topics: []string{realtimeTopicPlayer},
	})

	select {
	case notification := <-updates:
		if notification.UserID != userID {
			t.Fatalf("expected user %s, got %s", userID, notification.UserID)
		}
		if len(notification.Topics) != 1 || notification.Topics[0] != realtimeTopicPlayer {
			t.Fatalf("unexpected topics: %#v", notification.Topics)
		}
	case <-time.After(time.Second):
		t.Fatal("expected notification")
	}
}

func TestRealtimeBrokerMergesPendingTopics(t *testing.T) {
	broker := NewRealtimeBroker("")
	userID := uuid.New()

	updates, unsubscribe := broker.Subscribe(userID)
	defer unsubscribe()

	broker.dispatch(store.RealtimeNotification{
		UserID: userID,
		Topics: []string{realtimeTopicInventory},
	})
	broker.dispatch(store.RealtimeNotification{
		UserID: userID,
		Topics: []string{realtimeTopicPlayer, realtimeTopicInventory},
	})

	select {
	case notification := <-updates:
		if len(notification.Topics) != 2 {
			t.Fatalf("expected merged topics, got %#v", notification.Topics)
		}
		if notification.Topics[0] != realtimeTopicInventory || notification.Topics[1] != realtimeTopicPlayer {
			t.Fatalf("unexpected merged topics order/content: %#v", notification.Topics)
		}
	case <-time.After(time.Second):
		t.Fatal("expected merged notification")
	}
}
