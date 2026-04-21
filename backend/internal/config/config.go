package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port               int
	DatabaseURL        string
	AccessTokenSecret  string
	RefreshTokenSecret string
	AccessTokenTTL     time.Duration
	RefreshTokenTTL    time.Duration
	AllowedOrigins     []string
}

func Load() (Config, error) {
	cfg := Config{
		Port:               getInt("PORT", 8080),
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		AccessTokenSecret:  os.Getenv("ACCESS_TOKEN_SECRET"),
		RefreshTokenSecret: os.Getenv("REFRESH_TOKEN_SECRET"),
		AccessTokenTTL:     getDuration("ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL:    getDuration("REFRESH_TOKEN_TTL", 30*24*time.Hour),
		AllowedOrigins:     getList("ALLOWED_ORIGINS", []string{"http://localhost:3000", "http://localhost:8080"}),
	}

	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.AccessTokenSecret == "" || cfg.RefreshTokenSecret == "" {
		return Config{}, fmt.Errorf("ACCESS_TOKEN_SECRET and REFRESH_TOKEN_SECRET are required")
	}
	return cfg, nil
}

func getInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func getDuration(key string, fallback time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func getList(key string, fallback []string) []string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			items = append(items, trimmed)
		}
	}
	return items
}
