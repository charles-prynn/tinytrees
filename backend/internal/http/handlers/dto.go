package handlers

import (
	"net/http"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/service"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type userDTO struct {
	ID          string    `json:"id"`
	Provider    string    `json:"provider"`
	Username    *string   `json:"username,omitempty"`
	Email       *string   `json:"email,omitempty"`
	DisplayName string    `json:"display_name"`
	CreatedAt   time.Time `json:"created_at"`
}

type tokenDTO struct {
	AccessToken           string    `json:"access_token"`
	RefreshToken          string    `json:"refresh_token"`
	AccessTokenExpiresAt  time.Time `json:"access_token_expires_at"`
	RefreshTokenExpiresAt time.Time `json:"refresh_token_expires_at"`
}

type authDTO struct {
	User   userDTO  `json:"user"`
	Tokens tokenDTO `json:"tokens"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type passwordLoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type guestUpgradeRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type stateSyncRequest struct {
	Version  int64          `json:"version"`
	Metadata map[string]any `json:"metadata"`
}

type playerMoveRequest struct {
	TargetX int `json:"target_x"`
	TargetY int `json:"target_y"`
}

type harvestRequest struct {
	EntityID string `json:"entity_id"`
}

func (r harvestRequest) EntityUUID() (uuid.UUID, error) {
	return uuid.Parse(r.EntityID)
}

type bankDepositRequest struct {
	EntityID string `json:"entity_id"`
	ItemKey  string `json:"item_key"`
	Quantity int64  `json:"quantity"`
}

func (r bankDepositRequest) EntityUUID() (uuid.UUID, error) {
	return uuid.Parse(r.EntityID)
}

type adminGrantInventoryRequest struct {
	ItemKey  string `json:"item_key"`
	Quantity int64  `json:"quantity"`
}

type adminGrantXPRequest struct {
	SkillKey string `json:"skill_key"`
	XP       int64  `json:"xp"`
}

type adminSetPlayerPositionRequest struct {
	X int `json:"x"`
	Y int `json:"y"`
}

type tiledMapDTO struct {
	CompressionLevel int                `json:"compressionlevel"`
	Height           int                `json:"height"`
	Infinite         bool               `json:"infinite"`
	Layers           []tiledLayerDTO    `json:"layers"`
	NextLayerID      int                `json:"nextlayerid"`
	NextObjectID     int                `json:"nextobjectid"`
	Orientation      string             `json:"orientation"`
	Properties       []tiledPropertyDTO `json:"properties,omitempty"`
	RenderOrder      string             `json:"renderorder"`
	TiledVersion     string             `json:"tiledversion"`
	TileHeight       int                `json:"tileheight"`
	Tilesets         []tiledTilesetDTO  `json:"tilesets"`
	TileWidth        int                `json:"tilewidth"`
	Type             string             `json:"type"`
	Version          string             `json:"version"`
	Width            int                `json:"width"`
}

type tiledLayerDTO struct {
	Data    []int   `json:"data"`
	Height  int     `json:"height"`
	ID      int     `json:"id"`
	Name    string  `json:"name"`
	Opacity float64 `json:"opacity"`
	Type    string  `json:"type"`
	Visible bool    `json:"visible"`
	Width   int     `json:"width"`
	X       int     `json:"x"`
	Y       int     `json:"y"`
}

type tiledTilesetDTO struct {
	Columns     int    `json:"columns"`
	FirstGID    int    `json:"firstgid"`
	Image       string `json:"image"`
	ImageWidth  int    `json:"imagewidth"`
	ImageHeight int    `json:"imageheight"`
	Margin      int    `json:"margin"`
	Name        string `json:"name"`
	Spacing     int    `json:"spacing"`
	TileCount   int    `json:"tilecount"`
	TileHeight  int    `json:"tileheight"`
	TileWidth   int    `json:"tilewidth"`
}

type tiledPropertyDTO struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Value any    `json:"value"`
}

type entityDTO struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Type        string         `json:"type"`
	ResourceKey string         `json:"resource_key,omitempty"`
	X           int            `json:"x"`
	Y           int            `json:"y"`
	Width       int            `json:"width"`
	Height      int            `json:"height"`
	SpriteGID   int            `json:"sprite_gid"`
	State       string         `json:"state"`
	Metadata    map[string]any `json:"metadata"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

type pointDTO struct {
	X int `json:"x"`
	Y int `json:"y"`
}

type playerMovementDTO struct {
	FromX               int        `json:"from_x"`
	FromY               int        `json:"from_y"`
	TargetX             int        `json:"target_x"`
	TargetY             int        `json:"target_y"`
	Path                []pointDTO `json:"path"`
	StartedAt           time.Time  `json:"started_at"`
	ArrivesAt           time.Time  `json:"arrives_at"`
	SpeedTilesPerSecond float64    `json:"speed_tiles_per_second"`
}

type playerDTO struct {
	UserID    string             `json:"user_id"`
	X         int                `json:"x"`
	Y         int                `json:"y"`
	RenderX   float64            `json:"render_x"`
	RenderY   float64            `json:"render_y"`
	Movement  *playerMovementDTO `json:"movement,omitempty"`
	Action    *actionDTO         `json:"action,omitempty"`
	Skills    []playerSkillDTO   `json:"skills,omitempty"`
	UpdatedAt time.Time          `json:"updated_at"`
}

type actionDTO struct {
	ID             string         `json:"id"`
	Type           string         `json:"type"`
	EntityID       *string        `json:"entity_id,omitempty"`
	Status         string         `json:"status"`
	StartedAt      time.Time      `json:"started_at"`
	EndsAt         time.Time      `json:"ends_at"`
	NextTickAt     time.Time      `json:"next_tick_at"`
	TickIntervalMs int            `json:"tick_interval_ms"`
	Metadata       map[string]any `json:"metadata"`
	UpdatedAt      time.Time      `json:"updated_at"`
}

type eventDTO struct {
	ID            int64          `json:"id"`
	AggregateType string         `json:"aggregate_type"`
	AggregateID   *string        `json:"aggregate_id,omitempty"`
	EventType     string         `json:"event_type"`
	Payload       map[string]any `json:"payload"`
	CreatedAt     time.Time      `json:"created_at"`
}

type inventoryItemDTO struct {
	ItemKey   string    `json:"item_key"`
	Quantity  int64     `json:"quantity"`
	UpdatedAt time.Time `json:"updated_at"`
}

type playerSkillDTO struct {
	SkillKey  string    `json:"skill_key"`
	XP        int64     `json:"xp"`
	Level     int       `json:"level"`
	UpdatedAt time.Time `json:"updated_at"`
}

type adminOverviewDTO struct {
	GeneratedAt time.Time             `json:"generated_at"`
	Totals      adminTotalsDTO        `json:"totals"`
	Users       []adminUserSummaryDTO `json:"users"`
}

type adminTotalsDTO struct {
	TotalUsers    int `json:"total_users"`
	GuestUsers    int `json:"guest_users"`
	LocalUsers    int `json:"local_users"`
	ActivePlayers int `json:"active_players"`
	MovingPlayers int `json:"moving_players"`
	IdlePlayers   int `json:"idle_players"`
}

type adminUserSummaryDTO struct {
	User              userDTO   `json:"user"`
	PlayerX           int       `json:"player_x"`
	PlayerY           int       `json:"player_y"`
	Status            string    `json:"status"`
	WoodcuttingLevel  int       `json:"woodcutting_level"`
	WoodcuttingXP     int64     `json:"woodcutting_xp"`
	LastUpdatedAt     time.Time `json:"last_updated_at"`
	CurrentActionType string    `json:"current_action_type,omitempty"`
}

type adminUserDetailDTO struct {
	User   userDTO              `json:"user"`
	Player playerDTO            `json:"player"`
	Action *actionDTO           `json:"action,omitempty"`
	Skills []playerSkillDTO     `json:"skills"`
	Items  []inventoryItemDTO   `json:"items"`
	World  adminWorldSummaryDTO `json:"world"`
}

type adminWorldSummaryDTO struct {
	TotalEntities      int            `json:"total_entities"`
	ActiveResources    int            `json:"active_resources"`
	DepletedResources  int            `json:"depleted_resources"`
	ResourceCounts     map[string]int `json:"resource_counts"`
	ResourceStateCount map[string]int `json:"resource_state_count"`
}

func toUserDTO(user domain.User) userDTO {
	return userDTO{
		ID:          user.ID.String(),
		Provider:    user.Provider,
		Username:    user.Username,
		Email:       user.Email,
		DisplayName: user.DisplayName,
		CreatedAt:   user.CreatedAt,
	}
}

func toTokenDTO(tokens service.AuthTokens) tokenDTO {
	return tokenDTO{
		AccessToken:           tokens.AccessToken,
		RefreshToken:          tokens.RefreshToken,
		AccessTokenExpiresAt:  tokens.AccessTokenExpiresAt,
		RefreshTokenExpiresAt: tokens.RefreshTokenExpiresAt,
	}
}

func toAuthDTO(result service.AuthResult) authDTO {
	return authDTO{User: toUserDTO(result.User), Tokens: toTokenDTO(result.Tokens)}
}

func userIDFromParam(r *http.Request) (uuid.UUID, error) {
	return uuid.Parse(chi.URLParam(r, "userID"))
}

func toTiledMapDTO(tileMap domain.TileMap) tiledMapDTO {
	tiles := make([]int, len(tileMap.Tiles))
	copy(tiles, tileMap.Tiles)

	return tiledMapDTO{
		CompressionLevel: -1,
		Height:           tileMap.Height,
		Infinite:         false,
		Layers: []tiledLayerDTO{
			{
				Data:    tiles,
				Height:  tileMap.Height,
				ID:      1,
				Name:    "Ground",
				Opacity: 1,
				Type:    "tilelayer",
				Visible: true,
				Width:   tileMap.Width,
				X:       0,
				Y:       0,
			},
		},
		NextLayerID:  2,
		NextObjectID: 1,
		Orientation:  "orthogonal",
		Properties: []tiledPropertyDTO{
			{Name: "user_id", Type: "string", Value: tileMap.UserID.String()},
			{Name: "updated_at", Type: "string", Value: tileMap.UpdatedAt.Format(time.RFC3339Nano)},
		},
		RenderOrder:  "right-down",
		TiledVersion: "1.11.2",
		TileHeight:   tileMap.TileSize,
		Tilesets:     toTiledTilesetDTOs(tileMap),
		TileWidth:    tileMap.TileSize,
		Type:         "map",
		Version:      "1.10",
		Width:        tileMap.Width,
	}
}

func toTiledTilesetDTOs(tileMap domain.TileMap) []tiledTilesetDTO {
	if len(tileMap.Tilesets) == 0 {
		return []tiledTilesetDTO{
			{
				Columns:     8,
				FirstGID:    1,
				Image:       "tiles/tile_map.png",
				ImageWidth:  256,
				ImageHeight: 256,
				Name:        "tile_map",
				TileCount:   64,
				TileHeight:  tileMap.TileSize,
				TileWidth:   tileMap.TileSize,
			},
		}
	}

	tilesets := make([]tiledTilesetDTO, 0, len(tileMap.Tilesets))
	for _, tileset := range tileMap.Tilesets {
		tilesets = append(tilesets, tiledTilesetDTO{
			Columns:     tileset.Columns,
			FirstGID:    tileset.FirstGID,
			Image:       tileset.Image,
			ImageWidth:  tileset.ImageWidth,
			ImageHeight: tileset.ImageHeight,
			Margin:      tileset.Margin,
			Name:        tileset.Name,
			Spacing:     tileset.Spacing,
			TileCount:   tileset.TileCount,
			TileHeight:  tileset.TileHeight,
			TileWidth:   tileset.TileWidth,
		})
	}
	return tilesets
}

func toEntityDTOs(entities []domain.Entity) []entityDTO {
	items := make([]entityDTO, 0, len(entities))
	for _, entity := range entities {
		items = append(items, entityDTO{
			ID:          entity.ID.String(),
			Name:        entity.Name,
			Type:        entity.Type,
			ResourceKey: entity.ResourceKey,
			X:           entity.X,
			Y:           entity.Y,
			Width:       entity.Width,
			Height:      entity.Height,
			SpriteGID:   entity.SpriteGID,
			State:       entity.State,
			Metadata:    entity.Metadata,
			UpdatedAt:   entity.UpdatedAt,
		})
	}
	return items
}

func toPlayerDTO(player domain.Player) playerDTO {
	renderX, renderY := currentPlayerRenderPosition(player, time.Now().UTC())
	return playerDTO{
		UserID:    player.UserID.String(),
		X:         player.X,
		Y:         player.Y,
		RenderX:   renderX,
		RenderY:   renderY,
		Movement:  toPlayerMovementDTO(player.Movement),
		Action:    toActionDTO(player.Action),
		Skills:    toPlayerSkillDTOs(player.Skills),
		UpdatedAt: player.UpdatedAt,
	}
}

func currentPlayerRenderPosition(player domain.Player, now time.Time) (float64, float64) {
	movement := player.Movement
	if movement == nil || len(movement.Path) == 0 {
		return float64(player.X), float64(player.Y)
	}
	if !now.Before(movement.ArrivesAt) {
		return float64(movement.TargetX), float64(movement.TargetY)
	}
	if !now.After(movement.StartedAt) {
		first := movement.Path[0]
		return float64(first.X), float64(first.Y)
	}

	distance := now.Sub(movement.StartedAt).Seconds() * movement.SpeedTilesPerSecond
	for i := 0; i < len(movement.Path)-1; i++ {
		from := movement.Path[i]
		to := movement.Path[i+1]
		cost := pointStepCost(from, to)
		if distance <= cost {
			progress := 1.0
			if cost > 0 {
				progress = distance / cost
			}
			return lerpFloat(float64(from.X), float64(to.X), progress), lerpFloat(float64(from.Y), float64(to.Y), progress)
		}
		distance -= cost
	}

	last := movement.Path[len(movement.Path)-1]
	return float64(last.X), float64(last.Y)
}

func pointStepCost(from domain.Point, to domain.Point) float64 {
	dx := float64(from.X - to.X)
	if dx < 0 {
		dx = -dx
	}
	dy := float64(from.Y - to.Y)
	if dy < 0 {
		dy = -dy
	}
	if dx == 1 && dy == 1 {
		return 1.4142135623730951
	}
	if dx > dy {
		return dx
	}
	return dy
}

func lerpFloat(from float64, to float64, progress float64) float64 {
	if progress < 0 {
		progress = 0
	} else if progress > 1 {
		progress = 1
	}
	return from + (to-from)*progress
}

func toPlayerMovementDTO(movement *domain.PlayerMovement) *playerMovementDTO {
	if movement == nil {
		return nil
	}

	path := make([]pointDTO, 0, len(movement.Path))
	for _, point := range movement.Path {
		path = append(path, pointDTO{X: point.X, Y: point.Y})
	}

	return &playerMovementDTO{
		FromX:               movement.FromX,
		FromY:               movement.FromY,
		TargetX:             movement.TargetX,
		TargetY:             movement.TargetY,
		Path:                path,
		StartedAt:           movement.StartedAt,
		ArrivesAt:           movement.ArrivesAt,
		SpeedTilesPerSecond: movement.SpeedTilesPerSecond,
	}
}

func toActionDTO(action *domain.PlayerAction) *actionDTO {
	if action == nil {
		return nil
	}
	var entityID *string
	if action.EntityID != nil {
		value := action.EntityID.String()
		entityID = &value
	}
	return &actionDTO{
		ID:             action.ID.String(),
		Type:           action.Type,
		EntityID:       entityID,
		Status:         action.Status,
		StartedAt:      action.StartedAt,
		EndsAt:         action.EndsAt,
		NextTickAt:     action.NextTickAt,
		TickIntervalMs: action.TickIntervalMs,
		Metadata:       action.Metadata,
		UpdatedAt:      action.UpdatedAt,
	}
}

func toEventDTOs(events []domain.PlayerEvent) []eventDTO {
	result := make([]eventDTO, 0, len(events))
	for _, event := range events {
		result = append(result, toEventDTO(event))
	}
	return result
}

func toEventDTO(event domain.PlayerEvent) eventDTO {
	var aggregateID *string
	if event.AggregateID != nil {
		value := event.AggregateID.String()
		aggregateID = &value
	}
	return eventDTO{
		ID:            event.ID,
		AggregateType: event.AggregateType,
		AggregateID:   aggregateID,
		EventType:     event.EventType,
		Payload:       event.Payload,
		CreatedAt:     event.CreatedAt,
	}
}

func toInventoryDTOs(items []domain.InventoryItem) []inventoryItemDTO {
	result := make([]inventoryItemDTO, 0, len(items))
	for _, item := range items {
		result = append(result, inventoryItemDTO{
			ItemKey:   item.ItemKey,
			Quantity:  item.Quantity,
			UpdatedAt: item.UpdatedAt,
		})
	}
	return result
}

func toPlayerSkillDTOs(skills []domain.PlayerSkill) []playerSkillDTO {
	result := make([]playerSkillDTO, 0, len(skills))
	for _, skill := range skills {
		result = append(result, toPlayerSkillDTO(skill))
	}
	return result
}

func toPlayerSkillDTO(skill domain.PlayerSkill) playerSkillDTO {
	return playerSkillDTO{
		SkillKey:  skill.SkillKey,
		XP:        skill.XP,
		Level:     skill.Level,
		UpdatedAt: skill.UpdatedAt,
	}
}

func toAdminOverviewDTO(overview domain.AdminOverview) adminOverviewDTO {
	items := make([]adminUserSummaryDTO, 0, len(overview.Users))
	for _, user := range overview.Users {
		items = append(items, adminUserSummaryDTO{
			User:              toUserDTO(user.User),
			PlayerX:           user.PlayerX,
			PlayerY:           user.PlayerY,
			Status:            user.Status,
			WoodcuttingLevel:  user.WoodcuttingLevel,
			WoodcuttingXP:     user.WoodcuttingXP,
			LastUpdatedAt:     user.LastUpdatedAt,
			CurrentActionType: user.CurrentActionType,
		})
	}
	return adminOverviewDTO{
		GeneratedAt: overview.GeneratedAt,
		Totals: adminTotalsDTO{
			TotalUsers:    overview.Totals.TotalUsers,
			GuestUsers:    overview.Totals.GuestUsers,
			LocalUsers:    overview.Totals.LocalUsers,
			ActivePlayers: overview.Totals.ActivePlayers,
			MovingPlayers: overview.Totals.MovingPlayers,
			IdlePlayers:   overview.Totals.IdlePlayers,
		},
		Users: items,
	}
}

func toAdminUserDetailDTO(detail domain.AdminUserDetail) adminUserDetailDTO {
	return adminUserDetailDTO{
		User:   toUserDTO(detail.User),
		Player: toPlayerDTO(detail.Player),
		Action: toActionDTO(detail.Action),
		Skills: toPlayerSkillDTOs(detail.Skills),
		Items:  toInventoryDTOs(detail.Items),
		World: adminWorldSummaryDTO{
			TotalEntities:      detail.World.TotalEntities,
			ActiveResources:    detail.World.ActiveResources,
			DepletedResources:  detail.World.DepletedResources,
			ResourceCounts:     detail.World.ResourceCounts,
			ResourceStateCount: detail.World.ResourceStateCount,
		},
	}
}
