package service

import (
	"context"
	"errors"
	"net/mail"
	"strings"
	"time"

	"starter/backend/internal/auth"
	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

var ErrUnauthorized = errors.New("unauthorized")
var ErrEmailTaken = errors.New("email is already registered")

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

	return s.issueSession(ctx, user)
}

func (s *AuthService) LoginPassword(ctx context.Context, email string, password string) (AuthResult, error) {
	user, err := s.users.GetByEmail(ctx, normalizeEmail(email))
	if err != nil {
		return AuthResult{}, ErrUnauthorized
	}
	if user.Provider != "local" {
		return AuthResult{}, ErrUnauthorized
	}

	hash, err := s.passwordHashForUser(ctx, user.ID)
	if err != nil {
		return AuthResult{}, ErrUnauthorized
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)); err != nil {
		return AuthResult{}, ErrUnauthorized
	}

	return s.issueSession(ctx, user)
}

func (s *AuthService) UpgradeGuest(ctx context.Context, userID uuid.UUID, email string, password string, displayName string) (domain.User, error) {
	normalizedEmail, err := validateEmail(email)
	if err != nil {
		return domain.User{}, err
	}
	if err := validatePassword(password); err != nil {
		return domain.User{}, err
	}
	displayName = strings.TrimSpace(displayName)
	if displayName == "" {
		displayName = defaultDisplayName(normalizedEmail)
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return domain.User{}, err
	}

	user, err := s.users.UpgradeGuest(ctx, userID, normalizedEmail, string(passwordHash), displayName)
	if err != nil {
		if isUniqueViolation(err) {
			return domain.User{}, ErrEmailTaken
		}
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.User{}, ErrValidation
		}
		return domain.User{}, err
	}
	return user, nil
}

func (s *AuthService) issueSession(ctx context.Context, user domain.User) (AuthResult, error) {
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

func (s *AuthService) passwordHashForUser(ctx context.Context, userID uuid.UUID) (string, error) {
	return s.users.GetPasswordHash(ctx, userID)
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

func validateEmail(email string) (string, error) {
	normalized := normalizeEmail(email)
	if normalized == "" {
		return "", ErrValidation
	}
	parsed, err := mail.ParseAddress(normalized)
	if err != nil || !strings.EqualFold(parsed.Address, normalized) {
		return "", ErrValidation
	}
	return normalized, nil
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func validatePassword(password string) error {
	if len(password) < 8 {
		return ErrValidation
	}
	return nil
}

func defaultDisplayName(email string) string {
	local := strings.TrimSpace(strings.SplitN(email, "@", 2)[0])
	if local == "" {
		return "Player"
	}
	return local
}

func isUniqueViolation(err error) bool {
	type sqlStateCarrier interface {
		SQLState() string
	}
	var stateErr sqlStateCarrier
	if errors.As(err, &stateErr) {
		return stateErr.SQLState() == "23505"
	}
	return false
}
