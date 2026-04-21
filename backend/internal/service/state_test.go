package service

import (
	"context"
	"testing"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestStateServiceRejectsInvalidVersion(t *testing.T) {
	service := NewStateService(&memoryState{})
	_, err := service.Sync(context.Background(), domain.StateSnapshot{UserID: uuid.New()})
	if err != ErrInvalidStateVersion {
		t.Fatalf("expected ErrInvalidStateVersion, got %v", err)
	}
}

type memoryState struct {
	snapshot domain.StateSnapshot
}

func (m *memoryState) GetSnapshot(_ context.Context, userID uuid.UUID) (domain.StateSnapshot, error) {
	m.snapshot.UserID = userID
	return m.snapshot, nil
}

func (m *memoryState) SaveSnapshot(_ context.Context, snapshot domain.StateSnapshot) (domain.StateSnapshot, error) {
	m.snapshot = snapshot
	return snapshot, nil
}
