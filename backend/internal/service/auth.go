package service

import (
	"context"
	"errors"
	"time"

	"starter/backend/internal/auth"
	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

var ErrUnauthorized = errors.New("unauthorized")

type AuthTokens struct {
	AccessToken           string
	RefreshToken          string
	AccessTokenExpiresAt  time.Time
	RefreshTokenExpiresAt time.Time
}

type AuthResult struct {
	User   domain.User
	Tokens AuthTokens
}

type AuthService struct {
	users    store.UserStore
	sessions store.SessionStore
	tokens   auth.TokenManager
}

func NewAuthService(users store.UserStore, sessions store.SessionStore, tokens auth.TokenManager) *AuthService {
	return &AuthService{users: users, sessions: sessions, tokens: tokens}
}

func (s *AuthService) LoginGuest(ctx context.Context) (AuthResult, error) {
	user, err := s.users.CreateGuest(ctx)
	if err != nil {
		return AuthResult{}, err
	}

	sessionID := uuid.New()
	access, refresh, accessExpires, refreshExpires, err := s.tokens.MintPair(user.ID, sessionID)
	if err != nil {
		return AuthResult{}, err
	}

	_, err = s.sessions.Create(ctx, domain.Session{
		ID:          sessionID,
		UserID:      user.ID,
		RefreshHash: auth.HashToken(refresh),
		ExpiresAt:   refreshExpires,
	})
	if err != nil {
		return AuthResult{}, err
	}

	return AuthResult{
		User: user,
		Tokens: AuthTokens{
			AccessToken:           access,
			RefreshToken:          refresh,
			AccessTokenExpiresAt:  accessExpires,
			RefreshTokenExpiresAt: refreshExpires,
		},
	}, nil
}

func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (AuthTokens, error) {
	claims, err := s.tokens.ParseRefresh(refreshToken)
	if err != nil {
		return AuthTokens{}, ErrUnauthorized
	}
	session, err := s.sessions.Get(ctx, claims.SessionID)
	if err != nil || session.RevokedAt != nil || session.ExpiresAt.Before(time.Now().UTC()) {
		return AuthTokens{}, ErrUnauthorized
	}
	if session.RefreshHash != auth.HashToken(refreshToken) {
		return AuthTokens{}, ErrUnauthorized
	}

	access, refresh, accessExpires, refreshExpires, err := s.tokens.MintPair(claims.UserID, claims.SessionID)
	if err != nil {
		return AuthTokens{}, err
	}
	if err := s.sessions.UpdateRefreshHash(ctx, claims.SessionID, auth.HashToken(refresh), refreshExpires); err != nil {
		return AuthTokens{}, err
	}
	return AuthTokens{
		AccessToken:           access,
		RefreshToken:          refresh,
		AccessTokenExpiresAt:  accessExpires,
		RefreshTokenExpiresAt: refreshExpires,
	}, nil
}

func (s *AuthService) Logout(ctx context.Context, sessionID uuid.UUID) error {
	return s.sessions.Revoke(ctx, sessionID)
}

func (s *AuthService) CurrentUser(ctx context.Context, userID uuid.UUID) (domain.User, error) {
	return s.users.GetByID(ctx, userID)
}

func (s *AuthService) ParseAccessToken(token string) (*auth.Claims, error) {
	claims, err := s.tokens.ParseAccess(token)
	if err != nil {
		return nil, ErrUnauthorized
	}
	return claims, nil
}
