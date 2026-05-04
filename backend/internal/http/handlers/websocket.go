package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"sync"
	"time"

	"starter/backend/internal/http/middleware"
	"starter/backend/internal/http/response"
	"starter/backend/internal/service"
	"starter/backend/internal/store"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

const (
	wsWriteTimeout = 10 * time.Second
	wsReadLimit    = 32 * 1024
)

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

	upgrader := websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			if origin == "" {
				return true
			}
			if h.allowWSOrigin == nil {
				return true
			}
			return h.allowWSOrigin(r, origin)
		},
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	conn.SetReadLimit(wsReadLimit)
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	var writeMu sync.Mutex
	write := func(message wsServerMessage) error {
		writeMu.Lock()
		defer writeMu.Unlock()
		return writeWebSocketJSON(conn, message)
	}

	if h.realtime != nil {
		updates, unsubscribe := h.realtime.Subscribe(userID)
		defer unsubscribe()
		go h.pushRealtimeUpdates(ctx, userID, updates, write)
	}

	for {
		var message wsClientMessage
		if err := conn.ReadJSON(&message); err != nil {
			if websocket.IsCloseError(err, websocket.CloseNormalClosure, websocket.CloseGoingAway) {
				return
			}
			return
		}

		reply := h.handleWebSocketMessage(r, userID, message)
		if err := write(reply); err != nil {
			return
		}
	}
}

type wsRealtimeSnapshot struct {
	lastPlayerJSON    []byte
	lastActionJSON    []byte
	lastInventoryJSON []byte
	lastBankJSON      []byte
	lastEntityJSON    []byte
	lastInboxJSON     []byte
}

func (h *Handler) pushRealtimeUpdates(ctx context.Context, userID uuid.UUID, updates <-chan store.RealtimeNotification, write func(wsServerMessage) error) {
	snapshot := &wsRealtimeSnapshot{}

	for {
		select {
		case <-ctx.Done():
			return
		case notification := <-updates:
			if err := h.pushRealtimeNotification(ctx, userID, notification, snapshot, write); err != nil {
				return
			}
		}
	}
}

func (h *Handler) pushRealtimeNotification(ctx context.Context, userID uuid.UUID, notification store.RealtimeNotification, snapshot *wsRealtimeSnapshot, write func(wsServerMessage) error) error {
	topicSet := make(map[string]struct{}, len(notification.Topics))
	for _, topic := range notification.Topics {
		topicSet[topic] = struct{}{}
	}

	if _, ok := topicSet["player"]; ok {
		player, err := h.players.Get(ctx, userID)
		if err == nil {
			playerDTO := toPlayerDTO(player)
			playerJSON, err := json.Marshal(playerDTO)
			if err == nil && !jsonEqual(snapshot.lastPlayerJSON, playerJSON) {
				if err := write(wsServerMessage{
					Type: "player.updated",
					Data: map[string]any{"player": playerDTO},
				}); err != nil {
					return err
				}
				snapshot.lastPlayerJSON = playerJSON
			}

			actionDTO := toActionDTO(player.Action)
			actionJSON, err := json.Marshal(actionDTO)
			if err == nil && !jsonEqual(snapshot.lastActionJSON, actionJSON) {
				if err := write(wsServerMessage{
					Type: "action.updated",
					Data: map[string]any{"action": actionDTO},
				}); err != nil {
					return err
				}
				snapshot.lastActionJSON = actionJSON
			}
		}
	}

	if _, ok := topicSet["entities"]; ok {
		entities, err := h.entities.List(ctx, userID)
		if err == nil {
			entityDTOs := toEntityDTOs(entities)
			entityJSON, err := json.Marshal(entityDTOs)
			if err == nil && !jsonEqual(snapshot.lastEntityJSON, entityJSON) {
				if err := write(wsServerMessage{
					Type: "entities.updated",
					Data: map[string]any{"entities": entityDTOs},
				}); err != nil {
					return err
				}
				snapshot.lastEntityJSON = entityJSON
			}
		}
	}

	if _, ok := topicSet["inventory"]; ok {
		items, err := h.inventory.List(ctx, userID)
		if err == nil {
			inventoryDTOs := toInventoryDTOs(items)
			inventoryJSON, err := json.Marshal(inventoryDTOs)
			if err == nil && !jsonEqual(snapshot.lastInventoryJSON, inventoryJSON) {
				if err := write(wsServerMessage{
					Type: "inventory.updated",
					Data: map[string]any{"items": inventoryDTOs},
				}); err != nil {
					return err
				}
				snapshot.lastInventoryJSON = inventoryJSON
			}
		}
	}

	if _, ok := topicSet["bank"]; ok {
		items, err := h.inventory.ListBank(ctx, userID)
		if err == nil {
			bankDTOs := toInventoryDTOs(items)
			bankJSON, err := json.Marshal(bankDTOs)
			if err == nil && !jsonEqual(snapshot.lastBankJSON, bankJSON) {
				if err := write(wsServerMessage{
					Type: "bank.updated",
					Data: map[string]any{"items": bankDTOs},
				}); err != nil {
					return err
				}
				snapshot.lastBankJSON = bankJSON
			}
		}
	}

	if _, ok := topicSet["events"]; ok {
		items, err := h.events.ListInbox(ctx, userID, 0, 50)
		if err == nil {
			inboxDTOs := toInboxDTOs(items)
			inboxJSON, err := json.Marshal(inboxDTOs)
			if err == nil && !jsonEqual(snapshot.lastInboxJSON, inboxJSON) {
				if err := write(wsServerMessage{
					Type: "events.updated",
					Data: map[string]any{"items": inboxDTOs},
				}); err != nil {
					return err
				}
				snapshot.lastInboxJSON = inboxJSON
			}
		}
	}

	return nil
}

func jsonEqual(a []byte, b []byte) bool {
	if len(a) == 0 && len(b) == 0 {
		return true
	}
	return string(a) == string(b)
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
		player, err := h.players.Move(r.Context(), userID, body.TargetX, body.TargetY, body.ClientMoveID)
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
	case "events.inbox":
		items, err := h.events.ListInbox(r.Context(), userID, 0, 50)
		if err != nil {
			return wsError(message.ID, "events.inbox.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "events.updated",
			Data: map[string]any{"items": toInboxDTOs(items)},
		}
	case "events.ack":
		var body eventInboxAckRequest
		if err := decodeWebSocketPayload(message.Payload, &body); err != nil || !validInboxIDs(body.IDs) {
			return wsError(message.ID, "events.ack.error", service.ErrValidation)
		}
		items, err := h.events.AckInbox(r.Context(), userID, body.IDs)
		if err != nil {
			return wsError(message.ID, "events.ack.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "events.acked",
			Data: map[string]any{"items": toInboxDTOs(items)},
		}
	case "bank.get":
		items, err := h.inventory.ListBank(r.Context(), userID)
		if err != nil {
			return wsError(message.ID, "bank.get.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "bank.updated",
			Data: map[string]any{"items": toInventoryDTOs(items)},
		}
	case "bank.deposit":
		var body bankDepositRequest
		if err := decodeWebSocketPayload(message.Payload, &body); err != nil {
			return wsError(message.ID, "bank.deposit.error", service.ErrValidation)
		}
		entityID, err := body.EntityUUID()
		if err != nil {
			return wsError(message.ID, "bank.deposit.error", service.ErrValidation)
		}
		moved, err := h.inventory.Deposit(r.Context(), userID, entityID, body.ItemKey, body.Quantity)
		if err != nil {
			return wsError(message.ID, "bank.deposit.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "bank.deposited",
			Data: map[string]any{"moved": moved},
		}
	case "entities.get":
		entities, err := h.entities.List(r.Context(), userID)
		if err != nil {
			return wsError(message.ID, "entities.get.error", err)
		}
		return wsServerMessage{
			ID:   message.ID,
			Type: "entities.updated",
			Data: map[string]any{"entities": toEntityDTOs(entities)},
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
	case errors.Is(err, service.ErrUsernameTaken):
		code = "conflict"
		message = err.Error()
	case errors.Is(err, service.ErrEmailTaken):
		code = "conflict"
		message = err.Error()
	case errors.Is(err, service.ErrInsufficientLevel):
		code = "insufficient_level"
		message = err.Error()
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
