package handlers

import (
	"net/http"
	"strconv"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/http/middleware"
	"starter/backend/internal/http/response"
	"starter/backend/internal/service"
)

type Handler struct {
	auth          *service.AuthService
	state         *service.StateService
	maps          *service.MapService
	entities      *service.EntityService
	players       *service.PlayerService
	actions       *service.ActionService
	events        *service.EventService
	inventory     *service.InventoryService
	admin         *service.AdminService
	realtime      *service.RealtimeBroker
	allowWSOrigin func(r *http.Request, origin string) bool
}

func New(auth *service.AuthService, state *service.StateService, maps *service.MapService, entities *service.EntityService, players *service.PlayerService, actions *service.ActionService, events *service.EventService, inventory *service.InventoryService, admin *service.AdminService, realtime *service.RealtimeBroker, allowWSOrigin func(r *http.Request, origin string) bool) *Handler {
	return &Handler{
		auth:          auth,
		state:         state,
		maps:          maps,
		entities:      entities,
		players:       players,
		actions:       actions,
		events:        events,
		inventory:     inventory,
		admin:         admin,
		realtime:      realtime,
		allowWSOrigin: allowWSOrigin,
	}
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

func (h *Handler) PasswordLogin(w http.ResponseWriter, r *http.Request) {
	var body passwordLoginRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	result, err := h.auth.LoginPassword(r.Context(), body.Username, body.Password)
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

func (h *Handler) UpgradeGuest(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	var body guestUpgradeRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	user, err := h.auth.UpgradeGuest(r.Context(), userID, body.Username, body.Email, body.Password)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"user": toUserDTO(user)})
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
	player, err := h.players.Move(r.Context(), userID, body.TargetX, body.TargetY, body.ClientMoveID)
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

func (h *Handler) GetEventInbox(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}

	afterID, limit, err := parseAfterIDAndLimit(r)
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}

	items, err := h.events.ListInbox(r.Context(), userID, afterID, limit)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"items": toInboxDTOs(items)})
}

func (h *Handler) AckEventInbox(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}

	var body eventInboxAckRequest
	if err := response.DecodeJSON(r, &body); err != nil || !validInboxIDs(body.IDs) {
		response.Error(w, r, service.ErrValidation)
		return
	}

	items, err := h.events.AckInbox(r.Context(), userID, body.IDs)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"items": toInboxDTOs(items)})
}

func parseAfterIDAndLimit(r *http.Request) (int64, int, error) {
	afterID := int64(0)
	if raw := r.URL.Query().Get("after_id"); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || parsed < 0 {
			return 0, 0, service.ErrValidation
		}
		afterID = parsed
	}

	limit := 50
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed <= 0 || parsed > 200 {
			return 0, 0, service.ErrValidation
		}
		limit = parsed
	}
	return afterID, limit, nil
}

func validInboxIDs(ids []int64) bool {
	if len(ids) == 0 {
		return false
	}
	for _, id := range ids {
		if id <= 0 {
			return false
		}
	}
	return true
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

func (h *Handler) GetBank(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	items, err := h.inventory.ListBank(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"items": toInventoryDTOs(items)})
}

func (h *Handler) DepositBank(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserID(r.Context())
	if !ok {
		response.Error(w, r, service.ErrUnauthorized)
		return
	}
	var body bankDepositRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	entityID, err := body.EntityUUID()
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	moved, err := h.inventory.Deposit(r.Context(), userID, entityID, body.ItemKey, body.Quantity)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"moved": moved})
}

func (h *Handler) AdminOverview(w http.ResponseWriter, r *http.Request) {
	overview, err := h.admin.Overview(r.Context())
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"overview": toAdminOverviewDTO(overview)})
}

func (h *Handler) AdminUserDetail(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromParam(r)
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	detail, err := h.admin.UserDetail(r.Context(), userID)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"user": toAdminUserDetailDTO(detail)})
}

func (h *Handler) AdminGrantInventory(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromParam(r)
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	var body adminGrantInventoryRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	if err := h.admin.GrantInventory(r.Context(), userID, body.ItemKey, body.Quantity); err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"ok": true})
}

func (h *Handler) AdminGrantXP(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromParam(r)
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	var body adminGrantXPRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	skill, err := h.admin.GrantXP(r.Context(), userID, body.SkillKey, body.XP)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"skill": toPlayerSkillDTO(skill)})
}

func (h *Handler) AdminSetPlayerPosition(w http.ResponseWriter, r *http.Request) {
	userID, err := userIDFromParam(r)
	if err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	var body adminSetPlayerPositionRequest
	if err := response.DecodeJSON(r, &body); err != nil {
		response.Error(w, r, service.ErrValidation)
		return
	}
	player, err := h.admin.SetPlayerPosition(r.Context(), userID, body.X, body.Y)
	if err != nil {
		response.Error(w, r, err)
		return
	}
	response.JSON(w, r, http.StatusOK, map[string]any{"player": toPlayerDTO(player)})
}
