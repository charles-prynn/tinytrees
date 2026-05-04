package service

import (
	"context"
	"testing"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
)

func TestActionServiceProcessDueAwardsInventoryAndSkillXP(t *testing.T) {
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

	processed, err := service.ProcessDue(context.Background(), 1)
	if err != nil {
		t.Fatalf("ProcessDue returned error: %v", err)
	}
	if processed != 1 {
		t.Fatalf("expected 1 processed action, got %d", processed)
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
	if got := int64Metadata(actions.active.Metadata, "xp_granted", 0); got != 25 {
		t.Fatalf("expected action metadata xp_granted=25, got %d", got)
	}
	if got := int64Metadata(actions.active.Metadata, "current_level", 0); got != 1 {
		t.Fatalf("expected action metadata current_level=1, got %d", got)
	}
}

func TestActionServiceProcessDueRespectsInventorySlotLimit(t *testing.T) {
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
			"reward_quantity": int64(5),
			"success_chance":  1.0,
			"skill_key":       "woodcutting",
			"xp_per_reward":   int64(25),
		},
	}

	actions := &memoryActions{active: &action}
	inventory := &memoryInventory{
		items: map[string]int64{"wood": domain.InventorySlotLimit - 2},
	}
	skills := &memorySkills{}
	service := NewActionService(actions, inventory, skills, nil, nil)
	service.now = func() time.Time { return startedAt.Add(1500 * time.Millisecond) }

	processed, err := service.ProcessDue(context.Background(), 1)
	if err != nil {
		t.Fatalf("ProcessDue returned error: %v", err)
	}
	if processed != 1 {
		t.Fatalf("expected 1 processed action, got %d", processed)
	}
	if got := inventory.items["wood"]; got != domain.InventorySlotLimit {
		t.Fatalf("expected inventory to cap at %d, got %d", domain.InventorySlotLimit, got)
	}
	if got := int64Metadata(actions.active.Metadata, "rewards_granted", 0); got != 2 {
		t.Fatalf("expected 2 rewards granted after cap, got %d", got)
	}
	if got := int64Metadata(actions.active.Metadata, "xp_granted", 0); got != 50 {
		t.Fatalf("expected xp_granted to match accepted items, got %d", got)
	}
}

func TestActionServiceStartHarvestRequiresTreeLevel(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.April, 26, 12, 0, 0, 0, time.UTC)
	entityID := uuid.New()

	service := NewActionService(
		&memoryActions{},
		&memoryInventory{},
		&memorySkills{
			skills: map[string]domain.PlayerSkill{
				"woodcutting": {
					UserID:   userID,
					SkillKey: "woodcutting",
					Level:    44,
				},
			},
		},
		&memoryPlayerStore{
			player: domain.Player{UserID: userID, X: 9, Y: 9},
		},
		&memoryEntities{
			items: []domain.Entity{
				{
					ID:          entityID,
					UserID:      userID,
					Name:        "Maple Tree",
					Type:        "resource",
					ResourceKey: "maple_tree",
					X:           10,
					Y:           10,
					Width:       1,
					Height:      1,
					State:       resourceStateIdle,
					Metadata: map[string]any{
						"reward_item_key": "maple_logs",
						"reward_quantity": int64(1),
						"skill_key":       "woodcutting",
						"xp_per_reward":   int64(100),
						"required_level":  int64(45),
					},
				},
			},
		},
	)
	service.now = func() time.Time { return now }

	_, err := service.StartHarvest(context.Background(), userID, entityID)
	if err != ErrInsufficientLevel {
		t.Fatalf("expected ErrInsufficientLevel, got %v", err)
	}
}

func TestActionServiceStartHarvestUsesTreeHarvestDuration(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.April, 28, 12, 0, 0, 0, time.UTC)
	entityID := uuid.New()

	service := NewActionService(
		&memoryActions{},
		&memoryInventory{},
		&memorySkills{
			skills: map[string]domain.PlayerSkill{
				"woodcutting": {
					UserID:   userID,
					SkillKey: "woodcutting",
					Level:    75,
				},
			},
		},
		&memoryPlayerStore{
			player: domain.Player{UserID: userID, X: 9, Y: 9},
		},
		&memoryEntities{
			items: []domain.Entity{
				{
					ID:          entityID,
					UserID:      userID,
					Name:        "Magic Tree",
					Type:        "resource",
					ResourceKey: "magic_tree",
					X:           10,
					Y:           10,
					Width:       1,
					Height:      1,
					State:       resourceStateIdle,
					Metadata: map[string]any{
						"reward_item_key":          "magic_logs",
						"reward_quantity":          int64(1),
						"skill_key":                "woodcutting",
						"xp_per_reward":            int64(250),
						"required_level":           int64(75),
						"harvest_duration_seconds": int64(time.Hour / time.Second),
					},
				},
			},
		},
	)
	service.now = func() time.Time { return now }

	action, err := service.StartHarvest(context.Background(), userID, entityID)
	if err != nil {
		t.Fatalf("StartHarvest returned error: %v", err)
	}
	if got := action.EndsAt.Sub(action.StartedAt); got != time.Hour {
		t.Fatalf("expected harvest duration of 1 hour, got %s", got)
	}
	if got := action.Metadata["duration_seconds"]; got != float64(time.Hour/time.Second) {
		t.Fatalf("expected duration_seconds metadata to be 3600, got %#v", got)
	}
}

func TestActionServiceStartHarvestEmitsStartedEvent(t *testing.T) {
	userID := uuid.New()
	now := time.Date(2026, time.April, 28, 12, 0, 0, 0, time.UTC)
	entityID := uuid.New()
	events := &memoryEvents{}
	outbox := &memoryActionEventOutbox{}

	service := NewActionService(
		&memoryActions{},
		&memoryInventory{},
		&memorySkills{
			skills: map[string]domain.PlayerSkill{
				"woodcutting": {
					UserID:   userID,
					SkillKey: "woodcutting",
					Level:    15,
				},
			},
		},
		&memoryPlayerStore{
			player: domain.Player{UserID: userID, X: 9, Y: 9},
		},
		&memoryEntities{
			items: []domain.Entity{
				{
					ID:          entityID,
					UserID:      userID,
					Name:        "Oak Tree",
					Type:        "resource",
					ResourceKey: "oak_tree",
					X:           10,
					Y:           10,
					Width:       1,
					Height:      1,
					State:       resourceStateIdle,
					Metadata: map[string]any{
						"reward_item_key": "oak_logs",
						"reward_quantity": int64(1),
						"skill_key":       "woodcutting",
						"xp_per_reward":   int64(38),
						"required_level":  int64(15),
					},
				},
			},
		},
	)
	service.SetEventStore(events)
	service.SetEventOutboxStore(outbox)
	service.now = func() time.Time { return now }

	action, err := service.StartHarvest(context.Background(), userID, entityID)
	if err != nil {
		t.Fatalf("StartHarvest returned error: %v", err)
	}
	if len(events.events) != 1 {
		t.Fatalf("expected 1 emitted event, got %d", len(events.events))
	}
	event := events.events[0]
	if event.EventType != "action.started" {
		t.Fatalf("expected action.started event, got %q", event.EventType)
	}
	if event.AggregateID == nil || *event.AggregateID != action.ID {
		t.Fatalf("expected event aggregate_id %s, got %#v", action.ID, event.AggregateID)
	}
	if len(outbox.deliveries) != 0 {
		t.Fatalf("expected no inbox deliveries for action.started, got %d", len(outbox.deliveries))
	}
}

func TestActionServiceProcessDueDepletesTreeWhenHarvestDurationEnds(t *testing.T) {
	userID := uuid.New()
	entityID := uuid.New()
	startedAt := time.Date(2026, time.April, 26, 12, 0, 0, 0, time.UTC)
	action := domain.PlayerAction{
		ID:             uuid.New(),
		UserID:         userID,
		Type:           harvestActionType,
		EntityID:       &entityID,
		Status:         "active",
		StartedAt:      startedAt,
		EndsAt:         startedAt.Add(time.Second),
		NextTickAt:     startedAt.Add(time.Second),
		TickIntervalMs: 1000,
		Metadata: map[string]any{
			"reward_item_key": "oak_logs",
			"reward_quantity": int64(1),
			"success_chance":  1.0,
			"skill_key":       "woodcutting",
			"xp_per_reward":   int64(38),
		},
	}
	entities := &memoryEntities{
		items: []domain.Entity{
			{
				ID:          entityID,
				UserID:      userID,
				Name:        "Oak Tree",
				Type:        "resource",
				ResourceKey: "oak_tree",
				X:           10,
				Y:           10,
				Width:       1,
				Height:      1,
				State:       resourceStateIdle,
				Metadata:    map[string]any{},
			},
		},
	}

	actions := &memoryActions{active: &action}
	service := NewActionService(actions, &memoryInventory{}, &memorySkills{}, nil, entities)
	service.now = func() time.Time { return startedAt.Add(time.Second) }

	processed, err := service.ProcessDue(context.Background(), 1)
	if err != nil {
		t.Fatalf("ProcessDue returned error: %v", err)
	}
	if processed != 1 {
		t.Fatalf("expected 1 processed action, got %d", processed)
	}
	if actions.active == nil || actions.active.Status != "completed" {
		t.Fatalf("expected action to be completed, got %#v", actions.active)
	}
	if entities.items[0].State != resourceStateDepleted {
		t.Fatalf("expected entity to be depleted, got %q", entities.items[0].State)
	}
	if _, ok := entities.items[0].Metadata["stump_expires_at"]; !ok {
		t.Fatal("expected stump_expires_at metadata to be set")
	}
}

func TestActionServiceProcessDueEmitsCompletionEvents(t *testing.T) {
	userID := uuid.New()
	entityID := uuid.New()
	startedAt := time.Date(2026, time.April, 26, 12, 0, 0, 0, time.UTC)
	events := &memoryEvents{}
	outbox := &memoryActionEventOutbox{}
	action := domain.PlayerAction{
		ID:             uuid.New(),
		UserID:         userID,
		Type:           harvestActionType,
		EntityID:       &entityID,
		Status:         "active",
		StartedAt:      startedAt,
		EndsAt:         startedAt.Add(time.Second),
		NextTickAt:     startedAt.Add(time.Second),
		TickIntervalMs: 1000,
		Metadata: map[string]any{
			"resource_key":    "oak_tree",
			"reward_item_key": "oak_logs",
			"reward_quantity": int64(1),
			"success_chance":  1.0,
			"skill_key":       "woodcutting",
			"xp_per_reward":   int64(38),
			"current_level":   int64(1),
		},
	}
	entities := &memoryEntities{
		items: []domain.Entity{
			{
				ID:          entityID,
				UserID:      userID,
				Name:        "Oak Tree",
				Type:        "resource",
				ResourceKey: "oak_tree",
				X:           10,
				Y:           10,
				Width:       1,
				Height:      1,
				State:       resourceStateIdle,
				Metadata:    map[string]any{},
			},
		},
	}

	service := NewActionService(&memoryActions{active: &action}, &memoryInventory{}, &memorySkills{}, nil, entities)
	service.SetEventStore(events)
	service.SetEventOutboxStore(outbox)
	service.now = func() time.Time { return startedAt.Add(time.Second) }

	processed, err := service.ProcessDue(context.Background(), 1)
	if err != nil {
		t.Fatalf("ProcessDue returned error: %v", err)
	}
	if processed != 1 {
		t.Fatalf("expected 1 processed action, got %d", processed)
	}
	if len(events.events) != 2 {
		t.Fatalf("expected 2 emitted events, got %d", len(events.events))
	}
	if events.events[0].EventType != "resource.depleted" {
		t.Fatalf("expected first event resource.depleted, got %q", events.events[0].EventType)
	}
	if events.events[1].EventType != "action.completed" {
		t.Fatalf("expected second event action.completed, got %q", events.events[1].EventType)
	}
	if len(outbox.deliveries) != 1 {
		t.Fatalf("expected 1 inbox delivery, got %d", len(outbox.deliveries))
	}
	if outbox.deliveries[0].EventID != events.events[1].ID {
		t.Fatalf("expected inbox delivery for action.completed event %d, got %d", events.events[1].ID, outbox.deliveries[0].EventID)
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

func (m *memoryActions) ClaimNextDueAction(_ context.Context, now time.Time) (*domain.PlayerAction, error) {
	if m.active == nil || m.active.Status != "active" {
		return nil, nil
	}
	if now.Before(m.active.NextTickAt) && now.Before(m.active.EndsAt) {
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

type memoryInventory struct {
	items map[string]int64
}

func (m *memoryInventory) ListInventory(_ context.Context, _ uuid.UUID) ([]domain.InventoryItem, error) {
	return nil, nil
}

func (m *memoryInventory) AddInventoryItem(_ context.Context, _ uuid.UUID, itemKey string, quantity int64) (int64, error) {
	if m.items == nil {
		m.items = map[string]int64{}
	}
	current := m.items[itemKey]
	next := current + quantity
	if next > domain.InventorySlotLimit {
		next = domain.InventorySlotLimit
	}
	m.items[itemKey] = next
	return next - current, nil
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

type memoryEvents struct {
	events []domain.PlayerEvent
}

func (m *memoryEvents) GetEvent(_ context.Context, eventID int64) (domain.PlayerEvent, error) {
	for _, event := range m.events {
		if event.ID == eventID {
			return event, nil
		}
	}
	return domain.PlayerEvent{}, nil
}

func (m *memoryEvents) AppendEvents(_ context.Context, events []domain.PlayerEvent) ([]domain.PlayerEvent, error) {
	appended := make([]domain.PlayerEvent, 0, len(events))
	for _, event := range events {
		event.ID = int64(len(m.events) + 1)
		m.events = append(m.events, event)
		appended = append(appended, event)
	}
	return appended, nil
}

type memoryActionEventOutbox struct {
	deliveries []domain.PlayerEventDelivery
}

func (m *memoryActionEventOutbox) EnqueueDeliveries(_ context.Context, deliveries []domain.PlayerEventDelivery) ([]domain.PlayerEventDelivery, error) {
	appended := make([]domain.PlayerEventDelivery, 0, len(deliveries))
	for _, delivery := range deliveries {
		delivery.ID = int64(len(m.deliveries) + 1)
		m.deliveries = append(m.deliveries, delivery)
		appended = append(appended, delivery)
	}
	return appended, nil
}

func (m *memoryActionEventOutbox) ClaimNextPendingDelivery(_ context.Context, _ string, _ time.Time) (*domain.PlayerEventDelivery, error) {
	return nil, nil
}

func (m *memoryActionEventOutbox) MarkDeliveryDelivered(_ context.Context, _ int64, _ time.Time) error {
	return nil
}
