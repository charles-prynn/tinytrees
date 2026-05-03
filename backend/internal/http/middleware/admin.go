package middleware

import (
	"crypto/subtle"
	"net/http"
	"strings"

	"starter/backend/internal/http/response"
	"starter/backend/internal/service"
)

const adminSecretHeader = "X-Admin-Secret"

func Admin(secret string) func(http.Handler) http.Handler {
	expected := strings.TrimSpace(secret)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodOptions {
				next.ServeHTTP(w, r)
				return
			}
			provided := strings.TrimSpace(r.Header.Get(adminSecretHeader))
			if expected == "" || provided == "" {
				response.Error(w, r, service.ErrUnauthorized)
				return
			}
			if subtle.ConstantTimeCompare([]byte(provided), []byte(expected)) != 1 {
				response.Error(w, r, service.ErrUnauthorized)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
