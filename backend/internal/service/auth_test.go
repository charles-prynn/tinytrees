package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/auth"
	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestAuthServiceGuestLoginAndRefresh(t *testing.T) {
	users := &memoryUsers{}
	sessions := &memorySessions{items: map[uuid.UUID]domain.Session{}}
	tokenManager := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)
	service := NewAuthService(users, sessions, tokenManager)

	login, err := service.LoginGuest(context.Background())
	if err != nil {
		t.Fatalf("LoginGuest returned error: %v", err)
	}
	if login.User.Provider != "guest" || login.Tokens.AccessToken == "" || login.Tokens.RefreshToken == "" {
		t.Fatalf("unexpected login result: %+v", login)
	}

	refreshed, err := service.Refresh(context.Background(), login.Tokens.RefreshToken)
	if err != nil {
		t.Fatalf("Refresh returned error: %v", err)
	}
	if refreshed.AccessToken == "" || refreshed.RefreshToken == "" {
		t.Fatal("expected refreshed token pair")
	}
}

type memoryUsers struct {
	items []domain.User
}

func (m *memoryUsers) CreateGuest(_ context.Context) (domain.User, error) {
	user := domain.User{ID: uuid.New(), Provider: "guest", DisplayName: "Guest", CreatedAt: time.Now(), UpdatedAt: time.Now()}
	m.items = append(m.items, user)
	return user, nil
}

func (m *memoryUsers) GetByID(_ context.Context, id uuid.UUID) (domain.User, error) {
	for _, user := range m.items {
		if user.ID == id {
			return user, nil
		}
	}
	return domain.User{}, ErrUnauthorized
}

type memorySessions struct {
	items map[uuid.UUID]domain.Session
}

func (m *memorySessions) Create(_ context.Context, session domain.Session) (domain.Session, error) {
	session.CreatedAt = time.Now()
	session.LastUsedAt = time.Now()
	m.items[session.ID] = session
	return session, nil
}

func (m *memorySessions) Get(_ context.Context, id uuid.UUID) (domain.Session, error) {
	return m.items[id], nil
}

func (m *memorySessions) UpdateRefreshHash(_ context.Context, id uuid.UUID, refreshHash string, expiresAt time.Time) error {
	session := m.items[id]
	session.RefreshHash = refreshHash
	session.ExpiresAt = expiresAt
	m.items[id] = session
	return nil
}

func (m *memorySessions) Touch(_ context.Context, id uuid.UUID) error {
	return nil
}

func (m *memorySessions) Revoke(_ context.Context, id uuid.UUID) error {
	session := m.items[id]
	now := time.Now()
	session.RevokedAt = &now
	m.items[id] = session
	return nil
}
