package http

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"starter/backend/internal/config"
)

func TestHealthRouteIsMounted(t *testing.T) {
	router := NewRouter(
		config.Config{},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
	)
	request := httptest.NewRequest(http.MethodGet, "/health", nil)
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, response.Code)
	}

	var body struct {
		Data struct {
			Status string `json:"status"`
		} `json:"data"`
		Error any `json:"error"`
	}
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Data.Status != "ok" {
		t.Fatalf("expected health status ok, got %q", body.Data.Status)
	}
	if body.Error != nil {
		t.Fatalf("expected nil error, got %v", body.Error)
	}
}

func TestAdminRoutesRequireSharedSecret(t *testing.T) {
	router := NewRouter(
		config.Config{AdminSecret: "topsecret"},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
	)

	request := httptest.NewRequest(http.MethodGet, "/v1/admin/overview", nil)
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected status %d, got %d", http.StatusUnauthorized, response.Code)
	}
}

func TestAllowOriginAllowsConfiguredAndLocalDevOrigins(t *testing.T) {
	allow := allowOrigin([]string{"https://app.example.com", "http://localhost:3000"})
	request := &http.Request{}

	cases := map[string]bool{
		"https://app.example.com": true,
		"http://localhost:56128":  true,
		"http://127.0.0.1:56128":  true,
		"http://[::1]:56128":      true,
		"https://evil.example":    false,
		"file://localhost":        false,
	}

	for origin, expected := range cases {
		if got := allow(request, origin); got != expected {
			t.Fatalf("origin %q: expected %v, got %v", origin, expected, got)
		}
	}
}

func TestAllowOriginRejectsLocalDevOriginsWhenLocalhostIsNotConfigured(t *testing.T) {
	allow := allowOrigin([]string{"https://app.example.com"})

	if allow(&http.Request{}, "http://localhost:56128") {
		t.Fatal("expected localhost origin to be rejected without localhost in ALLOWED_ORIGINS")
	}
}
