package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"starter/backend/internal/http/middleware"
	"starter/backend/internal/http/response"
	"starter/backend/internal/service"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

const (
	wsWriteTimeout = 10 * time.Second
	wsReadLimit    = 32 * 1024
)

var wsUpgrader = websocket.Upgrader{}

type wsClientMessage struct {
	ID      string          `json:"id,omitempty"`
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type wsServerMessage struct {
	ID    string              `json:"id,omitempty"`
	Type  string              `json:"type"`
	Data  any                 `json:"data,omitempty"`
	Error *response.ErrorBody `json:"error,omitempty"`
}

func (h *Handler) WebSocket(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	conn.SetReadLimit(wsReadLimit)

	for {
		var message wsClientMessage
		if err := conn.ReadJSON(&message); err != nil {
			if websocket.IsCloseError(err, websocket.CloseNormalClosure, websocket.CloseGoingAway) {
				return
			}
			return
		}

		reply := h.handleWebSocketMessage(r, userID, message)
		if err := writeWebSocketJSON(conn, reply); err != nil {
			return
		}
	}
}

func (h *Handler) handleWebSocketMessage(r *http.Request, userID uuid.UUID, message wsClientMessage) wsServerMessage {
	switch message.Type {
	case "ping":
		return wsServerMessage{
			ID:   message.ID,
			Type: "pong",
			Data: map[string]any{"server_time": time.Now().UTC()},
		}
	case "player.get":
		player, err := h.players.Get(r.Context(), userID)
		if err != nil {
			return wsError(message.ID, message.Type+".error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "player.updated",
			Data: map[string]any{"player": toPlayerDTO(player)},
		}
	case "player.move":
		var body playerMoveRequest
		if err := decodeWebSocketPayload(message.Payload, &body); err != nil {
			return wsError(message.ID, "player.move.error", service.ErrValidation)
		}
		player, err := h.players.Move(r.Context(), userID, body.TargetX, body.TargetY)
		if err != nil {
			return wsError(message.ID, "player.move.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "player.updated",
			Data: map[string]any{"player": toPlayerDTO(player)},
		}
	case "actions.current":
		action, err := h.actions.Current(r.Context(), userID)
		if err != nil {
			return wsError(message.ID, "actions.current.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "action.updated",
			Data: map[string]any{"action": toActionDTO(action)},
		}
	case "actions.harvest":
		var body harvestRequest
		if err := decodeWebSocketPayload(message.Payload, &body); err != nil {
			return wsError(message.ID, "actions.harvest.error", service.ErrValidation)
		}
		entityID, err := body.EntityUUID()
		if err != nil {
			return wsError(message.ID, "actions.harvest.error", service.ErrValidation)
		}
		action, err := h.actions.StartHarvest(r.Context(), userID, entityID)
		if err != nil {
			return wsError(message.ID, "actions.harvest.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "action.started",
			Data: map[string]any{"action": toActionDTO(&action)},
		}
	case "inventory.get":
		items, err := h.inventory.List(r.Context(), userID)
		if err != nil {
			return wsError(message.ID, "inventory.get.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "inventory.updated",
			Data: map[string]any{"items": toInventoryDTOs(items)},
		}
	default:
		return wsError(message.ID, "message.error", service.ErrValidation)
	}
}

func decodeWebSocketPayload(payload json.RawMessage, dst any) error {
	if len(payload) == 0 {
		return errors.New("payload is required")
	}
	return json.Unmarshal(payload, dst)
}

func writeWebSocketJSON(conn *websocket.Conn, value any) error {
	if err := conn.SetWriteDeadline(time.Now().Add(wsWriteTimeout)); err != nil {
		return err
	}
	return conn.WriteJSON(value)
}

func wsError(id string, messageType string, err error) wsServerMessage {
	code := "internal_error"
	message := "internal server error"

	switch {
	case errors.Is(err, service.ErrUnauthorized):
		code = "unauthorized"
		message = "authentication is required"
	case errors.Is(err, service.ErrValidation),
		errors.Is(err, service.ErrInvalidStateVersion),
		errors.Is(err, service.ErrInvalidMoveTarget),
		errors.Is(err, service.ErrActionInProgress),
		errors.Is(err, service.ErrInvalidHarvestTarget),
		errors.Is(err, service.ErrPlayerIsMoving):
		code = "validation_error"
		message = err.Error()
	}

	return wsServerMessage{
		ID:    id,
		Type:  messageType,
		Error: &response.ErrorBody{Code: code, Message: message},
	}
}
