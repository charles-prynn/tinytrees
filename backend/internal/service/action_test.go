package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestActionServiceResolveAwardsInventoryAndSkillXP(t *testing.T) {
	userID := uuid.New()
	startedAt := time.Date(2026, time.April, 24, 10, 0, 0, 0, time.UTC)
	action := domain.PlayerAction{
		ID:             uuid.New(),
		UserID:         userID,
		Type:           harvestActionType,
		Status:         "active",
		StartedAt:      startedAt,
		EndsAt:         startedAt.Add(time.Minute),
		NextTickAt:     startedAt.Add(time.Second),
		TickIntervalMs: 1000,
		Metadata: map[string]any{
			"reward_item_key": "wood",
			"reward_quantity": int64(1),
			"success_chance":  1.0,
			"skill_key":       "woodcutting",
			"xp_per_reward":   int64(25),
		},
	}

	actions := &memoryActions{active: &action}
	inventory := &memoryInventory{}
	skills := &memorySkills{}
	service := NewActionService(actions, inventory, skills, nil, nil)
	service.now = func() time.Time { return startedAt.Add(1500 * time.Millisecond) }

	resolved, err := service.Resolve(context.Background(), userID)
	if err != nil {
		t.Fatalf("Resolve returned error: %v", err)
	}
	if resolved == nil {
		t.Fatal("expected active action")
	}
	if got := inventory.items["wood"]; got != 1 {
		t.Fatalf("expected 1 wood reward, got %d", got)
	}

	skill := skills.skills["woodcutting"]
	if skill.XP != 25 {
		t.Fatalf("expected 25 woodcutting xp, got %d", skill.XP)
	}
	if skill.Level != 1 {
		t.Fatalf("expected level 1 at 25 xp, got %d", skill.Level)
	}
	if got := int64Metadata(resolved.Metadata, "xp_granted", 0); got != 25 {
		t.Fatalf("expected action metadata xp_granted=25, got %d", got)
	}
	if got := int64Metadata(resolved.Metadata, "current_level", 0); got != 1 {
		t.Fatalf("expected action metadata current_level=1, got %d", got)
	}
}

type memoryActions struct {
	active *domain.PlayerAction
}

func (m *memoryActions) GetActiveAction(_ context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	if m.active == nil || m.active.UserID != userID {
		return nil, nil
	}
	action := *m.active
	if action.Metadata != nil {
		copyMetadata := make(map[string]any, len(action.Metadata))
		for key, value := range action.Metadata {
			copyMetadata[key] = value
		}
		action.Metadata = copyMetadata
	}
	return &action, nil
}

func (m *memoryActions) CreateAction(_ context.Context, action domain.PlayerAction) (domain.PlayerAction, error) {
	m.active = &action
	return action, nil
}

func (m *memoryActions) SaveAction(_ context.Context, action domain.PlayerAction) (domain.PlayerAction, error) {
	m.active = &action
	return action, nil
}

type memoryInventory struct {
	items map[string]int64
}

func (m *memoryInventory) ListInventory(_ context.Context, _ uuid.UUID) ([]domain.InventoryItem, error) {
	return nil, nil
}

func (m *memoryInventory) AddInventoryItem(_ context.Context, _ uuid.UUID, itemKey string, quantity int64) error {
	if m.items == nil {
		m.items = map[string]int64{}
	}
	m.items[itemKey] += quantity
	return nil
}

type memorySkills struct {
	skills map[string]domain.PlayerSkill
}

func (m *memorySkills) ListSkills(_ context.Context, _ uuid.UUID) ([]domain.PlayerSkill, error) {
	result := make([]domain.PlayerSkill, 0, len(m.skills))
	for _, skill := range m.skills {
		result = append(result, skill)
	}
	return result, nil
}

func (m *memorySkills) AddXP(_ context.Context, userID uuid.UUID, skillKey string, xp int64) (domain.PlayerSkill, error) {
	if m.skills == nil {
		m.skills = map[string]domain.PlayerSkill{}
	}
	skill := m.skills[skillKey]
	skill.UserID = userID
	skill.SkillKey = skillKey
	skill.XP += xp
	skill.Level = 1
	for skill.XP >= int64((skill.Level+1)*(skill.Level+1)*100-100) {
		skill.Level++
	}
	m.skills[skillKey] = skill
	return skill, nil
}
