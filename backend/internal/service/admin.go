package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrNotFound = errors.New("resource not found")

type AdminService struct {
	users          store.UserStore
	players        *PlayerService
	inventory      *InventoryService
	entities       *EntityService
	actions        *ActionService
	playerStore    store.PlayerStore
	mapStore       store.MapStore
	entityStore    store.EntityStore
	inventoryStore store.InventoryStore
	realtime       store.RealtimeStore
	skillStore     store.SkillStore
	now            func() time.Time
}

func NewAdminService(
	users store.UserStore,
	players *PlayerService,
	inventory *InventoryService,
	entities *EntityService,
	actions *ActionService,
	playerStore store.PlayerStore,
	mapStore store.MapStore,
	entityStore store.EntityStore,
	inventoryStore store.InventoryStore,
	skillStore store.SkillStore,
) *AdminService {
	return &AdminService{
		users:          users,
		players:        players,
		inventory:      inventory,
		entities:       entities,
		actions:        actions,
		playerStore:    playerStore,
		mapStore:       mapStore,
		entityStore:    entityStore,
		inventoryStore: inventoryStore,
		skillStore:     skillStore,
		now:            func() time.Time { return time.Now().UTC() },
	}
}

func (s *AdminService) SetRealtimeStore(realtime store.RealtimeStore) {
	s.realtime = realtime
}

func (s *AdminService) Overview(ctx context.Context) (domain.AdminOverview, error) {
	users, err := s.users.ListUsers(ctx)
	if err != nil {
		return domain.AdminOverview{}, err
	}

	overview := domain.AdminOverview{
		GeneratedAt: s.now(),
		Totals: domain.AdminTotals{
			TotalUsers: len(users),
		},
		Users: make([]domain.AdminUserSummary, 0, len(users)),
	}

	for _, user := range users {
		if user.Provider == "guest" {
			overview.Totals.GuestUsers++
		} else {
			overview.Totals.LocalUsers++
		}

		player, err := s.players.Get(ctx, user.ID)
		if err != nil {
			return domain.AdminOverview{}, err
		}

		level, xp := woodcuttingStats(player.Skills)
		status := adminPlayerStatus(player, s.now())
		switch status {
		case "Active":
			overview.Totals.ActivePlayers++
		case "Moving":
			overview.Totals.MovingPlayers++
		default:
			overview.Totals.IdlePlayers++
		}

		summary := domain.AdminUserSummary{
			User:             user,
			PlayerX:          player.X,
			PlayerY:          player.Y,
			Status:           status,
			WoodcuttingLevel: level,
			WoodcuttingXP:    xp,
			LastUpdatedAt:    player.UpdatedAt,
		}
		if player.Action != nil {
			summary.CurrentActionType = player.Action.Type
		}
		overview.Users = append(overview.Users, summary)
	}

	return overview, nil
}

func (s *AdminService) UserDetail(ctx context.Context, userID uuid.UUID) (domain.AdminUserDetail, error) {
	user, err := s.userByID(ctx, userID)
	if err != nil {
		return domain.AdminUserDetail{}, err
	}

	player, err := s.players.Get(ctx, userID)
	if err != nil {
		return domain.AdminUserDetail{}, err
	}
	items, err := s.inventory.List(ctx, userID)
	if err != nil {
		return domain.AdminUserDetail{}, err
	}
	entities, err := s.entities.List(ctx, userID)
	if err != nil {
		return domain.AdminUserDetail{}, err
	}

	return domain.AdminUserDetail{
		User:   user,
		Player: player,
		Action: player.Action,
		Skills: append([]domain.PlayerSkill(nil), player.Skills...),
		Items:  items,
		World:  summarizeAdminWorld(entities),
	}, nil
}

func (s *AdminService) GrantInventory(ctx context.Context, userID uuid.UUID, itemKey string, quantity int64) error {
	if quantity <= 0 {
		return ErrValidation
	}
	itemKey = normalizeAdminKey(itemKey)
	if itemKey == "" {
		return ErrValidation
	}
	if _, err := s.userByID(ctx, userID); err != nil {
		return err
	}
	if _, err := s.inventoryStore.AddInventoryItem(ctx, userID, itemKey, quantity); err != nil {
		return err
	}
	notifyRealtimeBestEffort(ctx, s.realtime, userID, realtimeTopicInventory)
	return nil
}

func (s *AdminService) GrantXP(ctx context.Context, userID uuid.UUID, skillKey string, xp int64) (domain.PlayerSkill, error) {
	if xp <= 0 {
		return domain.PlayerSkill{}, ErrValidation
	}
	skillKey = normalizeAdminKey(skillKey)
	if skillKey == "" {
		return domain.PlayerSkill{}, ErrValidation
	}
	if _, err := s.userByID(ctx, userID); err != nil {
		return domain.PlayerSkill{}, err
	}
	skill, err := s.skillStore.AddXP(ctx, userID, skillKey, xp)
	if err != nil {
		return domain.PlayerSkill{}, err
	}
	notifyRealtimeBestEffort(ctx, s.realtime, userID, realtimeTopicPlayer)
	return skill, nil
}

func (s *AdminService) SetPlayerPosition(ctx context.Context, userID uuid.UUID, x int, y int) (domain.Player, error) {
	if _, err := s.userByID(ctx, userID); err != nil {
		return domain.Player{}, err
	}

	tileMap, err := s.mapStore.GetTileMap(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	entities, err := ensureResourceNodes(ctx, s.entityStore, userID, s.now())
	if err != nil {
		return domain.Player{}, err
	}

	target := domain.Point{X: x, Y: y}
	if !isWalkable(tileMap, blockedEntityTiles(entities), target) {
		return domain.Player{}, ErrValidation
	}

	player, err := s.playerStore.GetPlayer(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		player = defaultPlayer(userID)
	} else if err != nil {
		return domain.Player{}, err
	}

	if s.actions != nil {
		if err := s.actions.CancelActive(ctx, userID); err != nil {
			return domain.Player{}, err
		}
	}

	player.X = x
	player.Y = y
	player.Movement = nil
	if _, err := s.playerStore.SavePlayer(ctx, player); err != nil {
		return domain.Player{}, err
	}
	notifyRealtimeBestEffort(ctx, s.realtime, userID, realtimeTopicPlayer)

	return s.players.Get(ctx, userID)
}

func (s *AdminService) userByID(ctx context.Context, userID uuid.UUID) (domain.User, error) {
	user, err := s.users.GetByID(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.User{}, ErrNotFound
	}
	return user, err
}

func normalizeAdminKey(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func woodcuttingStats(skills []domain.PlayerSkill) (int, int64) {
	for _, skill := range skills {
		if skill.SkillKey == "woodcutting" {
			return skill.Level, skill.XP
		}
	}
	return 1, 0
}

func adminPlayerStatus(player domain.Player, now time.Time) string {
	switch {
	case player.Action != nil:
		return "Active"
	case player.Movement != nil && now.Before(player.Movement.ArrivesAt):
		return "Moving"
	default:
		return "Idle"
	}
}

func summarizeAdminWorld(entities []domain.Entity) domain.AdminWorldSummary {
	summary := domain.AdminWorldSummary{
		TotalEntities:      len(entities),
		ResourceCounts:     map[string]int{},
		ResourceStateCount: map[string]int{},
	}
	for _, entity := range entities {
		if entity.Type != "resource" {
			continue
		}
		if entity.State == resourceStateDepleted {
			summary.DepletedResources++
		} else {
			summary.ActiveResources++
		}
		key := entity.ResourceKey
		if key == "" {
			key = "unknown"
		}
		summary.ResourceCounts[key]++
		state := entity.State
		if state == "" {
			state = "unknown"
		}
		summary.ResourceStateCount[state]++
	}
	return summary
}
