package store

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresTransactor struct {
	pool *pgxpool.Pool
}

func NewPostgresTransactor(pool *pgxpool.Pool) *PostgresTransactor {
	return &PostgresTransactor{pool: pool}
}

func (t *PostgresTransactor) WithinTx(ctx context.Context, fn func(Stores) error) error {
	tx, err := t.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	stores := Stores{
		Actions:     &PostgresActionTxStore{tx: tx},
		Events:      &PostgresEventTxStore{tx: tx},
		EventOutbox: &PostgresEventOutboxTxStore{tx: tx},
		EventInbox:  &PostgresEventInboxTxStore{tx: tx},
		Entities:    &PostgresEntityTxStore{tx: tx},
		Inventory:   &PostgresInventoryTxStore{tx: tx},
		Players:     &PostgresPlayerTxStore{tx: tx},
		Realtime:    &PostgresRealtimeTxStore{tx: tx},
		Skills:      &PostgresSkillTxStore{tx: tx},
	}
	if err := fn(stores); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

type PostgresActionTxStore struct {
	tx pgx.Tx
}

func (s *PostgresActionTxStore) GetActiveAction(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	return getActiveAction(ctx, s.tx, userID)
}

func (s *PostgresActionTxStore) CreateAction(ctx context.Context, action domain.PlayerAction) (domain.PlayerAction, error) {
	return createAction(ctx, s.tx, action)
}

func (s *PostgresActionTxStore) SaveAction(ctx context.Context, action domain.PlayerAction) (domain.PlayerAction, error) {
	return saveAction(ctx, s.tx, action)
}

func (s *PostgresActionTxStore) ClaimNextDueAction(ctx context.Context, now time.Time) (*domain.PlayerAction, error) {
	return claimNextDueAction(ctx, s.tx, now)
}

type PostgresEntityTxStore struct {
	tx pgx.Tx
}

func (s *PostgresEntityTxStore) ListEntities(ctx context.Context, userID uuid.UUID) ([]domain.Entity, error) {
	rows, err := s.tx.Query(ctx, `
		select id, user_id, name, type, resource_key, x, y, width, height, sprite_gid, state, metadata, created_at, updated_at
		from user_entities
		where user_id = $1
		order by created_at asc, id asc
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	entities := []domain.Entity{}
	for rows.Next() {
		var entity domain.Entity
		var metadata []byte
		if err := rows.Scan(
			&entity.ID,
			&entity.UserID,
			&entity.Name,
			&entity.Type,
			&entity.ResourceKey,
			&entity.X,
			&entity.Y,
			&entity.Width,
			&entity.Height,
			&entity.SpriteGID,
			&entity.State,
			&metadata,
			&entity.CreatedAt,
			&entity.UpdatedAt,
		); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(metadata, &entity.Metadata); err != nil {
			entity.Metadata = map[string]any{}
		}
		entities = append(entities, entity)
	}
	return entities, rows.Err()
}

func (s *PostgresEntityTxStore) CreateEntity(ctx context.Context, entity domain.Entity) (domain.Entity, error) {
	return createEntity(ctx, s.tx, entity)
}

func (s *PostgresEntityTxStore) SaveEntity(ctx context.Context, entity domain.Entity) (domain.Entity, error) {
	return saveEntity(ctx, s.tx, entity)
}

func (s *PostgresEntityTxStore) DeleteEntity(ctx context.Context, userID uuid.UUID, entityID uuid.UUID) error {
	_, err := s.tx.Exec(ctx, `
		delete from user_entities
		where id = $1 and user_id = $2
	`, entityID, userID)
	return err
}

type PostgresInventoryTxStore struct {
	tx pgx.Tx
}

func (s *PostgresInventoryTxStore) ListInventory(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error) {
	rows, err := s.tx.Query(ctx, `
		select user_id, item_key, quantity, updated_at
		from player_inventory
		where user_id = $1
		  and quantity > 0
		order by item_key
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.InventoryItem{}
	for rows.Next() {
		var item domain.InventoryItem
		if err := rows.Scan(&item.UserID, &item.ItemKey, &item.Quantity, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *PostgresInventoryTxStore) AddInventoryItem(ctx context.Context, userID uuid.UUID, itemKey string, quantity int64) (int64, error) {
	if quantity <= 0 {
		return 0, nil
	}

	var before int64
	var after int64
	err := s.tx.QueryRow(ctx, `
		with existing as (
			select quantity
			from player_inventory
			where user_id = $1 and item_key = $2
		), upsert as (
			insert into player_inventory (user_id, item_key, quantity)
			values ($1, $2, least($3::bigint, $4::bigint))
			on conflict (user_id, item_key) do update set
				quantity = case
					when player_inventory.quantity >= $3::bigint then player_inventory.quantity
					else least($3::bigint, player_inventory.quantity + excluded.quantity)
				end,
				updated_at = case
					when player_inventory.quantity < $3::bigint and least($3::bigint, player_inventory.quantity + excluded.quantity) <> player_inventory.quantity then now()
					else player_inventory.updated_at
				end
			returning quantity
		)
		select
			coalesce((select quantity from existing), 0),
			(select quantity from upsert)
	`, userID, itemKey, domain.InventorySlotLimit, quantity).Scan(&before, &after)
	if err != nil {
		return 0, err
	}
	return after - before, nil
}

type PostgresPlayerTxStore struct {
	tx pgx.Tx
}

func (s *PostgresPlayerTxStore) GetPlayer(ctx context.Context, userID uuid.UUID) (domain.Player, error) {
	var player domain.Player
	var movement []byte
	err := s.tx.QueryRow(ctx, `
		select user_id, x, y, movement, created_at, updated_at
		from players
		where user_id = $1
	`, userID).Scan(
		&player.UserID,
		&player.X,
		&player.Y,
		&movement,
		&player.CreatedAt,
		&player.UpdatedAt,
	)
	if err != nil {
		return domain.Player{}, err
	}
	player.Movement = decodeMovement(movement)
	return player, nil
}

func (s *PostgresPlayerTxStore) CreatePlayer(ctx context.Context, player domain.Player) (domain.Player, error) {
	movement, err := encodeMovement(player.Movement)
	if err != nil {
		return domain.Player{}, err
	}
	err = s.tx.QueryRow(ctx, `
		insert into players (user_id, x, y, movement)
		values ($1, $2, $3, $4)
		returning created_at, updated_at
	`, player.UserID, player.X, player.Y, movement).Scan(&player.CreatedAt, &player.UpdatedAt)
	return player, err
}

func (s *PostgresPlayerTxStore) SavePlayer(ctx context.Context, player domain.Player) (domain.Player, error) {
	movement, err := encodeMovement(player.Movement)
	if err != nil {
		return domain.Player{}, err
	}
	err = s.tx.QueryRow(ctx, `
		insert into players (user_id, x, y, movement)
		values ($1, $2, $3, $4)
		on conflict (user_id) do update set
			x = excluded.x,
			y = excluded.y,
			movement = excluded.movement,
			updated_at = now()
		returning created_at, updated_at
	`, player.UserID, player.X, player.Y, movement).Scan(&player.CreatedAt, &player.UpdatedAt)
	return player, err
}

type PostgresSkillTxStore struct {
	tx pgx.Tx
}

func (s *PostgresSkillTxStore) ListSkills(ctx context.Context, userID uuid.UUID) ([]domain.PlayerSkill, error) {
	rows, err := s.tx.Query(ctx, `
		select user_id, skill_key, xp, level, updated_at
		from player_skills
		where user_id = $1
		order by skill_key
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	skills := []domain.PlayerSkill{}
	for rows.Next() {
		var skill domain.PlayerSkill
		if err := rows.Scan(&skill.UserID, &skill.SkillKey, &skill.XP, &skill.Level, &skill.UpdatedAt); err != nil {
			return nil, err
		}
		skills = append(skills, skill)
	}
	return skills, rows.Err()
}

func (s *PostgresSkillTxStore) AddXP(ctx context.Context, userID uuid.UUID, skillKey string, xp int64) (domain.PlayerSkill, error) {
	var skill domain.PlayerSkill
	err := s.tx.QueryRow(ctx, `
		insert into player_skills (user_id, skill_key, xp, level)
		values ($1, $2, $3, $4)
		on conflict (user_id, skill_key) do update set
			xp = player_skills.xp + excluded.xp,
			updated_at = now()
		returning user_id, skill_key, xp, level, updated_at
	`, userID, skillKey, xp, skillLevelForXP(xp)).Scan(
		&skill.UserID,
		&skill.SkillKey,
		&skill.XP,
		&skill.Level,
		&skill.UpdatedAt,
	)
	if err != nil {
		return domain.PlayerSkill{}, err
	}

	skill.Level = skillLevelForXP(skill.XP)
	err = s.tx.QueryRow(ctx, `
		update player_skills
		set level = $3, updated_at = now()
		where user_id = $1 and skill_key = $2
		returning updated_at
	`, userID, skillKey, skill.Level).Scan(&skill.UpdatedAt)
	if err != nil {
		return domain.PlayerSkill{}, err
	}
	return skill, nil
}

func (s *PostgresActionStore) ClaimNextDueAction(ctx context.Context, now time.Time) (*domain.PlayerAction, error) {
	return claimNextDueAction(ctx, s.pool, now)
}

func getActiveAction(ctx context.Context, db pgxQuery, userID uuid.UUID) (*domain.PlayerAction, error) {
	row := db.QueryRow(ctx, `
		select id, user_id, type, entity_id, status, started_at, ends_at, next_tick_at, tick_interval_ms, metadata, created_at, updated_at
		from player_actions
		where user_id = $1 and status = 'active'
		order by started_at desc
		limit 1
	`, userID)
	return scanAction(row)
}

func createAction(ctx context.Context, db pgxQuery, action domain.PlayerAction) (domain.PlayerAction, error) {
	if action.ID == uuid.Nil {
		action.ID = uuid.New()
	}
	if action.Metadata == nil {
		action.Metadata = map[string]any{}
	}
	metadata, err := json.Marshal(action.Metadata)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	err = db.QueryRow(ctx, `
		insert into player_actions (id, user_id, type, entity_id, status, started_at, ends_at, next_tick_at, tick_interval_ms, metadata)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		returning created_at, updated_at
	`,
		action.ID,
		action.UserID,
		action.Type,
		action.EntityID,
		action.Status,
		action.StartedAt,
		action.EndsAt,
		action.NextTickAt,
		action.TickIntervalMs,
		metadata,
	).Scan(&action.CreatedAt, &action.UpdatedAt)
	return action, err
}

func saveAction(ctx context.Context, db pgxQuery, action domain.PlayerAction) (domain.PlayerAction, error) {
	if action.Metadata == nil {
		action.Metadata = map[string]any{}
	}
	metadata, err := json.Marshal(action.Metadata)
	if err != nil {
		return domain.PlayerAction{}, err
	}
	err = db.QueryRow(ctx, `
		update player_actions
		set status = $2,
			ends_at = $3,
			next_tick_at = $4,
			metadata = $5,
			updated_at = now()
		where id = $1
		returning created_at, updated_at
	`, action.ID, action.Status, action.EndsAt, action.NextTickAt, metadata).Scan(&action.CreatedAt, &action.UpdatedAt)
	return action, err
}

func claimNextDueAction(ctx context.Context, db pgxQuery, now time.Time) (*domain.PlayerAction, error) {
	row := db.QueryRow(ctx, `
		with next_action as (
			select id
			from player_actions
			where status = 'active'
			  and (next_tick_at <= $1 or ends_at <= $1)
			order by least(next_tick_at, ends_at), started_at, id
			for update skip locked
			limit 1
		)
		select id, user_id, type, entity_id, status, started_at, ends_at, next_tick_at, tick_interval_ms, metadata, created_at, updated_at
		from player_actions
		where id = (select id from next_action)
	`, now)
	return scanAction(row)
}

func scanAction(row interface {
	Scan(...any) error
}) (*domain.PlayerAction, error) {
	var action domain.PlayerAction
	var entityID *uuid.UUID
	var metadata []byte
	err := row.Scan(
		&action.ID,
		&action.UserID,
		&action.Type,
		&entityID,
		&action.Status,
		&action.StartedAt,
		&action.EndsAt,
		&action.NextTickAt,
		&action.TickIntervalMs,
		&metadata,
		&action.CreatedAt,
		&action.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	action.EntityID = entityID
	if err := json.Unmarshal(metadata, &action.Metadata); err != nil {
		action.Metadata = map[string]any{}
	}
	return &action, nil
}

func createEntity(ctx context.Context, db pgxQuery, entity domain.Entity) (domain.Entity, error) {
	if entity.ID == uuid.Nil {
		entity.ID = uuid.New()
	}
	if entity.Metadata == nil {
		entity.Metadata = map[string]any{}
	}
	if entity.Name == "" {
		entity.Name = "Entity"
	}
	metadata, err := json.Marshal(entity.Metadata)
	if err != nil {
		return domain.Entity{}, err
	}

	err = db.QueryRow(ctx, `
		insert into user_entities (id, user_id, name, type, resource_key, x, y, width, height, sprite_gid, state, metadata)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		returning created_at, updated_at
	`,
		entity.ID,
		entity.UserID,
		entity.Name,
		entity.Type,
		entity.ResourceKey,
		entity.X,
		entity.Y,
		entity.Width,
		entity.Height,
		entity.SpriteGID,
		entity.State,
		metadata,
	).Scan(&entity.CreatedAt, &entity.UpdatedAt)
	return entity, err
}

func saveEntity(ctx context.Context, db pgxQuery, entity domain.Entity) (domain.Entity, error) {
	if entity.Metadata == nil {
		entity.Metadata = map[string]any{}
	}
	metadata, err := json.Marshal(entity.Metadata)
	if err != nil {
		return domain.Entity{}, err
	}
	err = db.QueryRow(ctx, `
		update user_entities
		set name = $3,
		    type = $4,
		    resource_key = $5,
		    x = $6,
		    y = $7,
		    width = $8,
		    height = $9,
		    sprite_gid = $10,
		    state = $11,
		    metadata = $12,
		    updated_at = now()
		where id = $1 and user_id = $2
		returning created_at, updated_at
	`,
		entity.ID,
		entity.UserID,
		entity.Name,
		entity.Type,
		entity.ResourceKey,
		entity.X,
		entity.Y,
		entity.Width,
		entity.Height,
		entity.SpriteGID,
		entity.State,
		metadata,
	).Scan(&entity.CreatedAt, &entity.UpdatedAt)
	return entity, err
}
