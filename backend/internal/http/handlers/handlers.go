package handlers

import (
	"net/http"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/http/middleware"
	"starter/backend/internal/http/response"
	"starter/backend/internal/service"
)

type Handler struct {
	auth      *service.AuthService
	state     *service.StateService
	maps      *service.MapService
	entities  *service.EntityService
	players   *service.PlayerService
	actions   *service.ActionService
	inventory *service.InventoryService
}

func New(auth *service.AuthService, state *service.StateService, maps *service.MapService, entities *service.EntityService, players *service.PlayerService, actions *service.ActionService, inventory *service.InventoryService) *Handler {
	return &Handler{auth: auth, state: state, maps: maps, entities: entities, players: players, actions: actions, inventory: inventory}
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	response.JSON(w, r, http.StatusOK, map[string]any{"status": "ok", "time": time.Now().UTC()})
}

func (h *Handler) GuestLogin(w http.ResponseWriter, r *http.Request) {
	result, err := h.auth.LoginGuest(r.Context())
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, toAuthDTO(result))
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var body refreshRequest
	if err := response.DecodeJSON(r, &body); err != nil || body.RefreshToken == "" {
		response.Error(w, r, service.ErrValidation)
		return
	}
	tokens, err := h.auth.Refresh(r.Context(), body.RefreshToken)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"tokens": toTokenDTO(tokens)})
}

func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	sessionID, ok := middleware.SessionID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	if err := h.auth.Logout(r.Context(), sessionID); err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"ok": true})
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	user, err := h.auth.CurrentUser(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"user": toUserDTO(user)})
}

func (h *Handler) Bootstrap(w http.ResponseWriter, r *http.Request) {
	response.JSON(w, r, http.StatusOK, map[string]any{
		"config": map[string]any{
			"api_version": "v1",
			"features":    []string{},
		},
		"server_time": time.Now().UTC(),
	})
}

func (h *Handler) GetState(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	snapshot, err := h.state.Load(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"snapshot": snapshot})
}

func (h *Handler) SyncState(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	var body stateSyncRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	snapshot, err := h.state.Sync(r.Context(), domain.StateSnapshot{
		UserID:   userID,
		Version:  body.Version,
		Metadata: body.Metadata,
	})
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"snapshot": snapshot})
}

func (h *Handler) GetMap(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	tileMap, err := h.maps.Load(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"map": toTiledMapDTO(tileMap)})
}

func (h *Handler) GetEntities(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	entities, err := h.entities.List(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"entities": toEntityDTOs(entities)})
}

func (h *Handler) GetPlayer(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	player, err := h.players.Get(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"player": toPlayerDTO(player)})
}

func (h *Handler) MovePlayer(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	var body playerMoveRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	player, err := h.players.Move(r.Context(), userID, body.TargetX, body.TargetY)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"player": toPlayerDTO(player)})
}

func (h *Handler) StartHarvest(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	var body harvestRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	entityID, err := body.EntityUUID()
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	action, err := h.actions.StartHarvest(r.Context(), userID, entityID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"action": toActionDTO(&action)})
}

func (h *Handler) CurrentAction(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	action, err := h.actions.Current(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"action": toActionDTO(action)})
}

func (h *Handler) GetInventory(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	items, err := h.inventory.List(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"items": toInventoryDTOs(items)})
}
