package response

import (
	"encoding/json"
	"errors"
	"net/http"

	"starter/backend/internal/service"

	chimiddleware "github.com/go-chi/chi/v5/middleware"
)

type Envelope struct {
	Data      any        `json:"data,omitempty"`
	Error     *ErrorBody `json:"error,omitempty"`
	RequestID string     `json:"request_id,omitempty"`
}

type ErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func JSON(w http.ResponseWriter, r *http.Request, status int, data any) {
	write(w, r, status, Envelope{Data: data})
}

func Error(w http.ResponseWriter, r *http.Request, err error) {
	status := http.StatusInternalServerError
	code := "internal_error"
	message := "internal server error"

	switch {
	case errors.Is(err, service.ErrUnauthorized):
		status = http.StatusUnauthorized
		code = "unauthorized"
		message = "authentication is required"
	case errors.Is(err, service.ErrNotFound):
		status = http.StatusNotFound
		code = "not_found"
		message = err.Error()
	case errors.Is(err, service.ErrUsernameTaken):
		status = http.StatusConflict
		code = "conflict"
		message = err.Error()
	case errors.Is(err, service.ErrEmailTaken):
		status = http.StatusConflict
		code = "conflict"
		message = err.Error()
	case errors.Is(err, service.ErrInsufficientLevel):
		status = http.StatusBadRequest
		code = "insufficient_level"
		message = err.Error()
	case errors.Is(err, service.ErrValidation),
		errors.Is(err, service.ErrInvalidStateVersion),
		errors.Is(err, service.ErrInvalidMoveTarget),
		errors.Is(err, service.ErrActionInProgress),
		errors.Is(err, service.ErrInvalidHarvestTarget),
		errors.Is(err, service.ErrPlayerIsMoving),
		errors.Is(err, service.ErrInvalidBankTarget),
		errors.Is(err, service.ErrBankTooFar),
		errors.Is(err, service.ErrInvalidBankDeposit),
		errors.Is(err, service.ErrInventoryItemUnavailable):
		status = http.StatusBadRequest
		code = "validation_error"
		message = err.Error()
	}

	write(w, r, status, Envelope{Error: &ErrorBody{Code: code, Message: message}})
}

func DecodeJSON(r *http.Request, dst any) error {
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	return decoder.Decode(dst)
}

func write(w http.ResponseWriter, r *http.Request, status int, envelope Envelope) {
	envelope.RequestID = RequestID(r)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(envelope)
}

func RequestID(r *http.Request) string {
	if id := chimiddleware.GetReqID(r.Context()); id != "" {
		return id
	}
	if id := r.Header.Get("X-Request-ID"); id != "" {
		return id
	}
	return ""
}
