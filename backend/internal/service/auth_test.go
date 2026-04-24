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

func TestAuthServiceUpgradeGuestAndLoginPassword(t *testing.T) {
	users := &memoryUsers{passwords: map[uuid.UUID]string{}}
	sessions := &memorySessions{items: map[uuid.UUID]domain.Session{}}
	tokenManager := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)
	service := NewAuthService(users, sessions, tokenManager)

	login, err := service.LoginGuest(context.Background())
	if err != nil {
		t.Fatalf("LoginGuest returned error: %v", err)
	}

	upgraded, err := service.UpgradeGuest(context.Background(), login.User.ID, "player_one", "player@example.com", "password123")
	if err != nil {
		t.Fatalf("UpgradeGuest returned error: %v", err)
	}
	if upgraded.Provider != "local" || upgraded.Username == nil || *upgraded.Username != "player_one" || upgraded.DisplayName != "player_one" {
		t.Fatalf("unexpected upgraded user: %+v", upgraded)
	}

	authResult, err := service.LoginPassword(context.Background(), "player_one", "password123")
	if err != nil {
		t.Fatalf("LoginPassword returned error: %v", err)
	}
	if authResult.User.ID != login.User.ID {
		t.Fatalf("expected password login to reuse guest user id %s, got %s", login.User.ID, authResult.User.ID)
	}
}

type memoryUsers struct {
	items     []domain.User
	passwords map[uuid.UUID]string
}

func (m *memoryUsers) CreateGuest(_ context.Context) (domain.User, error) {
	user := domain.User{ID: uuid.New(), Provider: "guest", DisplayName: "Guest", CreatedAt: time.Now(), UpdatedAt: time.Now()}
	m.items = append(m.items, user)
	return user, nil
}

func (m *memoryUsers) GetByEmail(_ context.Context, email string) (domain.User, error) {
	for _, user := range m.items {
		if user.Email != nil && *user.Email == email {
			return user, nil
		}
	}
	return domain.User{}, ErrUnauthorized
}

func (m *memoryUsers) GetByUsername(_ context.Context, username string) (domain.User, error) {
	for _, user := range m.items {
		if user.Username != nil && *user.Username == username {
			return user, nil
		}
	}
	return domain.User{}, ErrUnauthorized
}

func (m *memoryUsers) GetByID(_ context.Context, id uuid.UUID) (domain.User, error) {
	for _, user := range m.items {
		if user.ID == id {
			return user, nil
		}
	}
	return domain.User{}, ErrUnauthorized
}

func (m *memoryUsers) GetPasswordHash(_ context.Context, id uuid.UUID) (string, error) {
	hash, ok := m.passwords[id]
	if !ok {
		return "", ErrUnauthorized
	}
	return hash, nil
}

func (m *memoryUsers) UpgradeGuest(_ context.Context, id uuid.UUID, username string, email *string, passwordHash string, displayName string) (domain.User, error) {
	for index, user := range m.items {
		if user.ID != id {
			continue
		}
		user.Provider = "local"
		user.Username = &username
		user.Email = email
		user.DisplayName = displayName
		user.UpdatedAt = time.Now()
		m.items[index] = user
		if m.passwords == nil {
			m.passwords = map[uuid.UUID]string{}
		}
		m.passwords[id] = passwordHash
		return user, nil
	}
	return domain.User{}, ErrValidation
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
