package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type TokenKind string

const (
	AccessToken  TokenKind = "access"
	RefreshToken TokenKind = "refresh"
)

type Claims struct {
	UserID    uuid.UUID `json:"user_id"`
	SessionID uuid.UUID `json:"session_id"`
	Kind      TokenKind `json:"kind"`
	jwt.RegisteredClaims
}

type TokenManager struct {
	accessSecret  []byte
	refreshSecret []byte
	accessTTL     time.Duration
	refreshTTL    time.Duration
}

func NewTokenManager(accessSecret, refreshSecret string, accessTTL, refreshTTL time.Duration) TokenManager {
	return TokenManager{
		accessSecret:  []byte(accessSecret),
		refreshSecret: []byte(refreshSecret),
		accessTTL:     accessTTL,
		refreshTTL:    refreshTTL,
	}
}

func (m TokenManager) MintPair(userID, sessionID uuid.UUID) (string, string, time.Time, time.Time, error) {
	now := time.Now().UTC()
	accessExpires := now.Add(m.accessTTL)
	refreshExpires := now.Add(m.refreshTTL)

	access, err := m.mint(userID, sessionID, AccessToken, accessExpires)
	if err != nil {
		return "", "", time.Time{}, time.Time{}, err
	}
	refresh, err := m.mint(userID, sessionID, RefreshToken, refreshExpires)
	if err != nil {
		return "", "", time.Time{}, time.Time{}, err
	}
	return access, refresh, accessExpires, refreshExpires, nil
}

func (m TokenManager) ParseAccess(token string) (*Claims, error) {
	return m.parse(token, AccessToken, m.accessSecret)
}

func (m TokenManager) ParseRefresh(token string) (*Claims, error) {
	return m.parse(token, RefreshToken, m.refreshSecret)
}

func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func (m TokenManager) mint(userID, sessionID uuid.UUID, kind TokenKind, expiresAt time.Time) (string, error) {
	claims := Claims{
		UserID:    userID,
		SessionID: sessionID,
		Kind:      kind,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			ID:        uuid.NewString(),
			IssuedAt:  jwt.NewNumericDate(time.Now().UTC()),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}
	secret := m.accessSecret
	if kind == RefreshToken {
		secret = m.refreshSecret
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(secret)
}

func (m TokenManager) parse(tokenValue string, kind TokenKind, secret []byte) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenValue, &Claims{}, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return secret, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid || claims.Kind != kind {
		return nil, fmt.Errorf("invalid token")
	}
	return claims, nil
}
