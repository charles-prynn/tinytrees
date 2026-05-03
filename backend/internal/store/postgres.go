package store

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStores struct {
	Users     *PostgresUserStore
	Sessions  *PostgresSessionStore
	State     *PostgresStateStore
	Maps      *PostgresMapStore
	Entities  *PostgresEntityStore
	Players   *PostgresPlayerStore
	Inventory *PostgresInventoryStore
	Bank      *PostgresBankStore
	Skills    *PostgresSkillStore
	Actions   *PostgresActionStore
}

func NewPostgresStores(pool *pgxpool.Pool) PostgresStores {
	return PostgresStores{
		Users:     &PostgresUserStore{pool: pool},
		Sessions:  &PostgresSessionStore{pool: pool},
		State:     &PostgresStateStore{pool: pool},
		Maps:      &PostgresMapStore{pool: pool},
		Entities:  &PostgresEntityStore{pool: pool},
		Players:   &PostgresPlayerStore{pool: pool},
		Inventory: &PostgresInventoryStore{pool: pool},
		Bank:      &PostgresBankStore{pool: pool},
		Skills:    &PostgresSkillStore{pool: pool},
		Actions:   &PostgresActionStore{pool: pool},
	}
}

func (s PostgresStores) Interfaces() Stores {
	return Stores{
		Users:     s.Users,
		Sessions:  s.Sessions,
		State:     s.State,
		Maps:      s.Maps,
		Entities:  s.Entities,
		Players:   s.Players,
		Inventory: s.Inventory,
		Bank:      s.Bank,
		Skills:    s.Skills,
		Actions:   s.Actions,
	}
}

type PostgresUserStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresUserStore) CreateGuest(ctx context.Context) (domain.User, error) {
	user := domain.User{ID: uuid.New(), Provider: "guest", DisplayName: "Guest"}
	err := s.pool.QueryRow(ctx, `
		insert into users (id, provider, display_name)
		values ($1, $2, $3)
		returning created_at, updated_at
	`, user.ID, user.Provider, user.DisplayName).Scan(&user.CreatedAt, &user.UpdatedAt)
	return user, err
}

func (s *PostgresUserStore) GetByEmail(ctx context.Context, email string) (domain.User, error) {
	var user domain.User
	err := s.pool.QueryRow(ctx, `
		select id, provider, username, email, display_name, created_at, updated_at
		from users
		where lower(email) = lower($1)
	`, email).Scan(&user.ID, &user.Provider, &user.Username, &user.Email, &user.DisplayName, &user.CreatedAt, &user.UpdatedAt)
	return user, err
}

func (s *PostgresUserStore) GetByUsername(ctx context.Context, username string) (domain.User, error) {
	var user domain.User
	err := s.pool.QueryRow(ctx, `
		select id, provider, username, email, display_name, created_at, updated_at
		from users
		where lower(username) = lower($1)
	`, username).Scan(&user.ID, &user.Provider, &user.Username, &user.Email, &user.DisplayName, &user.CreatedAt, &user.UpdatedAt)
	return user, err
}

func (s *PostgresUserStore) GetByID(ctx context.Context, id uuid.UUID) (domain.User, error) {
	var user domain.User
	err := s.pool.QueryRow(ctx, `
		select id, provider, username, email, display_name, created_at, updated_at
		from users
		where id = $1
	`, id).Scan(&user.ID, &user.Provider, &user.Username, &user.Email, &user.DisplayName, &user.CreatedAt, &user.UpdatedAt)
	return user, err
}

func (s *PostgresUserStore) ListUsers(ctx context.Context) ([]domain.User, error) {
	rows, err := s.pool.Query(ctx, `
		select id, provider, username, email, display_name, created_at, updated_at
		from users
		order by created_at desc, id desc
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := []domain.User{}
	for rows.Next() {
		var user domain.User
		if err := rows.Scan(
			&user.ID,
			&user.Provider,
			&user.Username,
			&user.Email,
			&user.DisplayName,
			&user.CreatedAt,
			&user.UpdatedAt,
		); err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, rows.Err()
}

func (s *PostgresUserStore) GetPasswordHash(ctx context.Context, id uuid.UUID) (string, error) {
	var passwordHash string
	err := s.pool.QueryRow(ctx, `
		select password_hash
		from users
		where id = $1
	`, id).Scan(&passwordHash)
	return passwordHash, err
}

func (s *PostgresUserStore) UpgradeGuest(ctx context.Context, id uuid.UUID, username string, email *string, passwordHash string, displayName string) (domain.User, error) {
	var user domain.User
	err := s.pool.QueryRow(ctx, `
		update users
		set provider = 'local',
		    username = $2,
		    email = $3,
		    password_hash = $4,
		    display_name = $5,
		    updated_at = now()
		where id = $1 and provider = 'guest'
		returning id, provider, username, email, display_name, created_at, updated_at
	`, id, username, email, passwordHash, displayName).Scan(&user.ID, &user.Provider, &user.Username, &user.Email, &user.DisplayName, &user.CreatedAt, &user.UpdatedAt)
	return user, err
}

type PostgresSessionStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresSessionStore) Create(ctx context.Context, session domain.Session) (domain.Session, error) {
	err := s.pool.QueryRow(ctx, `
		insert into sessions (id, user_id, refresh_hash, expires_at)
		values ($1, $2, $3, $4)
		returning created_at, last_used_at
	`, session.ID, session.UserID, session.RefreshHash, session.ExpiresAt).Scan(&session.CreatedAt, &session.LastUsedAt)
	return session, err
}

func (s *PostgresSessionStore) Get(ctx context.Context, id uuid.UUID) (domain.Session, error) {
	var session domain.Session
	err := s.pool.QueryRow(ctx, `
		select id, user_id, refresh_hash, expires_at, revoked_at, created_at, last_used_at
		from sessions
		where id = $1
	`, id).Scan(&session.ID, &session.UserID, &session.RefreshHash, &session.ExpiresAt, &session.RevokedAt, &session.CreatedAt, &session.LastUsedAt)
	return session, err
}

func (s *PostgresSessionStore) UpdateRefreshHash(ctx context.Context, id uuid.UUID, refreshHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx, `
		update sessions
		set refresh_hash = $2, expires_at = $3, last_used_at = now()
		where id = $1 and revoked_at is null
	`, id, refreshHash, expiresAt)
	return err
}

func (s *PostgresSessionStore) Touch(ctx context.Context, id uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `update sessions set last_used_at = now() where id = $1`, id)
	return err
}

func (s *PostgresSessionStore) Revoke(ctx context.Context, id uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `update sessions set revoked_at = now() where id = $1 and revoked_at is null`, id)
	return err
}

type PostgresStateStore struct {
	pool *pgxpool.Pool
}

type snapshotRow struct {
	Version     int64           `json:"version"`
	Resources   json.RawMessage `json:"resources"`
	Assignments json.RawMessage `json:"assignments"`
	Items       json.RawMessage `json:"items"`
	Upgrades    json.RawMessage `json:"upgrades"`
	Metadata    json.RawMessage `json:"metadata"`
}

func (s *PostgresStateStore) GetSnapshot(ctx context.Context, userID uuid.UUID) (domain.StateSnapshot, error) {
	var payload []byte
	var updatedAt time.Time
	err := s.pool.QueryRow(ctx, `select payload, updated_at from state_snapshots where user_id = $1`, userID).Scan(&payload, &updatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return emptySnapshot(userID), nil
	}
	if err != nil {
		return domain.StateSnapshot{}, err
	}
	return decodeSnapshot(userID, payload, updatedAt)
}

func (s *PostgresStateStore) SaveSnapshot(ctx context.Context, snapshot domain.StateSnapshot) (domain.StateSnapshot, error) {
	payload, err := encodeSnapshot(snapshot)
	if err != nil {
		return domain.StateSnapshot{}, err
	}
	err = s.pool.QueryRow(ctx, `
		insert into state_snapshots (user_id, version, payload)
		values ($1, $2, $3)
		on conflict (user_id) do update
		set version = excluded.version, payload = excluded.payload, updated_at = now()
		returning updated_at
	`, snapshot.UserID, snapshot.Version, payload).Scan(&snapshot.UpdatedAt)
	return snapshot, err
}

func emptySnapshot(userID uuid.UUID) domain.StateSnapshot {
	return domain.StateSnapshot{
		UserID:      userID,
		Version:     1,
		Resources:   []domain.Resource{},
		Assignments: []domain.Assignment{},
		Items:       []domain.Item{},
		Upgrades:    []domain.Upgrade{},
		Metadata:    map[string]any{},
		UpdatedAt:   time.Now().UTC(),
	}
}

func encodeSnapshot(snapshot domain.StateSnapshot) ([]byte, error) {
	return json.Marshal(snapshotRow{
		Version:     snapshot.Version,
		Resources:   mustJSON(snapshot.Resources),
		Assignments: mustJSON(snapshot.Assignments),
		Items:       mustJSON(snapshot.Items),
		Upgrades:    mustJSON(snapshot.Upgrades),
		Metadata:    mustJSON(snapshot.Metadata),
	})
}

func decodeSnapshot(userID uuid.UUID, payload []byte, updatedAt time.Time) (domain.StateSnapshot, error) {
	var row snapshotRow
	if err := json.Unmarshal(payload, &row); err != nil {
		return domain.StateSnapshot{}, err
	}
	snapshot := emptySnapshot(userID)
	snapshot.Version = row.Version
	snapshot.UpdatedAt = updatedAt
	_ = json.Unmarshal(row.Resources, &snapshot.Resources)
	_ = json.Unmarshal(row.Assignments, &snapshot.Assignments)
	_ = json.Unmarshal(row.Items, &snapshot.Items)
	_ = json.Unmarshal(row.Upgrades, &snapshot.Upgrades)
	_ = json.Unmarshal(row.Metadata, &snapshot.Metadata)
	return snapshot, nil
}

func mustJSON(value any) json.RawMessage {
	payload, err := json.Marshal(value)
	if err != nil {
		return json.RawMessage(`null`)
	}
	return payload
}

type PostgresMapStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresMapStore) GetTileMap(ctx context.Context, userID uuid.UUID) (domain.TileMap, error) {
	var payload []byte
	var updatedAt time.Time
	err := s.pool.QueryRow(ctx, `select payload, updated_at from user_maps where user_id = $1`, userID).Scan(&payload, &updatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return DefaultTileMap(userID), nil
	}
	if err != nil {
		return domain.TileMap{}, err
	}

	var tileMap domain.TileMap
	if err := json.Unmarshal(payload, &tileMap); err != nil {
		return domain.TileMap{}, err
	}
	tileMap.UserID = userID
	tileMap.UpdatedAt = updatedAt
	return tileMap, nil
}

func (s *PostgresMapStore) SaveTileMap(ctx context.Context, tileMap domain.TileMap) (domain.TileMap, error) {
	payload, err := json.Marshal(tileMap)
	if err != nil {
		return domain.TileMap{}, err
	}

	err = s.pool.QueryRow(ctx, `
		insert into user_maps (user_id, payload)
		values ($1, $2)
		on conflict (user_id) do update
		set payload = excluded.payload, updated_at = now()
		returning updated_at
	`, tileMap.UserID, payload).Scan(&tileMap.UpdatedAt)
	return tileMap, err
}

func DefaultTileMap(userID uuid.UUID) domain.TileMap {
	template := defaultTileMapTemplate()

	return domain.TileMap{
		UserID:    userID,
		Width:     template.Width,
		Height:    template.Height,
		TileSize:  template.TileSize,
		Tiles:     append([]int(nil), template.Tiles...),
		Tilesets:  copyTilesets(template.Tilesets),
		UpdatedAt: time.Now().UTC(),
	}
}

var (
	tileMapTemplateOnce sync.Once
	tileMapTemplate     domain.TileMap
)

type tiledTemplate struct {
	Width      int                  `json:"width"`
	Height     int                  `json:"height"`
	TileWidth  int                  `json:"tilewidth"`
	TileHeight int                  `json:"tileheight"`
	Layers     []tiledTemplateLayer `json:"layers"`
	Tilesets   []domain.Tileset     `json:"tilesets"`
}

type tiledTemplateLayer struct {
	Type string `json:"type"`
	Data []int  `json:"data"`
}

func defaultTileMapTemplate() domain.TileMap {
	tileMapTemplateOnce.Do(func() {
		tileMapTemplate = loadTileMapTemplate()
	})
	return tileMapTemplate
}

func loadTileMapTemplate() domain.TileMap {
	if path := os.Getenv("TILEMAP_PATH"); path != "" {
		if tileMap, err := readTileMapTemplate(path); err == nil {
			return tileMap
		}
	}

	for _, path := range []string{
		"tilemap.json",
		filepath.Join("backend", "tilemap.json"),
		filepath.Join("..", "..", "tilemap.json"),
		filepath.Join("..", "..", "..", "tilemap.json"),
		filepath.Join("/app", "tilemap.json"),
	} {
		if tileMap, err := readTileMapTemplate(path); err == nil {
			return tileMap
		}
	}

	return fallbackTileMapTemplate()
}

func readTileMapTemplate(path string) (domain.TileMap, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return domain.TileMap{}, err
	}

	var template tiledTemplate
	if err := json.Unmarshal(payload, &template); err != nil {
		return domain.TileMap{}, err
	}

	tileSize := template.TileWidth
	if tileSize <= 0 {
		tileSize = template.TileHeight
	}
	if tileSize <= 0 {
		tileSize = domain.DefaultTileMapTileSize
	}

	tiles := firstTileLayerData(template.Layers)
	if len(tiles) != template.Width*template.Height {
		return domain.TileMap{}, errors.New("tilemap template has invalid layer data")
	}
	normalizeTileIDs(tiles)

	return domain.TileMap{
		Width:    template.Width,
		Height:   template.Height,
		TileSize: tileSize,
		Tiles:    tiles,
		Tilesets: normalizeTilesets(template.Tilesets, tileSize),
	}, nil
}

func firstTileLayerData(layers []tiledTemplateLayer) []int {
	for _, layer := range layers {
		if layer.Type == "tilelayer" {
			return append([]int(nil), layer.Data...)
		}
	}
	return nil
}

func fallbackTileMapTemplate() domain.TileMap {
	tiles := make([]int, domain.DefaultTileMapWidth*domain.DefaultTileMapHeight)
	for index := range tiles {
		tiles[index] = 1
	}
	return domain.TileMap{
		Width:    domain.DefaultTileMapWidth,
		Height:   domain.DefaultTileMapHeight,
		TileSize: domain.DefaultTileMapTileSize,
		Tiles:    tiles,
		Tilesets: []domain.Tileset{
			{
				Columns:     8,
				FirstGID:    1,
				Image:       "tiles/tile_map.png",
				ImageWidth:  256,
				ImageHeight: 256,
				Name:        "tile_map",
				TileCount:   64,
				TileHeight:  domain.DefaultTileMapTileSize,
				TileWidth:   domain.DefaultTileMapTileSize,
			},
		},
	}
}

func normalizeTileIDs(tiles []int) {
	for index, tileID := range tiles {
		if tileID <= 0 {
			tiles[index] = 1
		}
	}
}

func normalizeTilesets(tilesets []domain.Tileset, tileSize int) []domain.Tileset {
	if len(tilesets) == 0 {
		return fallbackTileMapTemplate().Tilesets
	}
	next := copyTilesets(tilesets)
	for index := range next {
		next[index].Image = "tiles/tile_map.png"
		if next[index].TileWidth <= 0 {
			next[index].TileWidth = tileSize
		}
		if next[index].TileHeight <= 0 {
			next[index].TileHeight = tileSize
		}
	}
	return next
}

func copyTilesets(tilesets []domain.Tileset) []domain.Tileset {
	return append([]domain.Tileset(nil), tilesets...)
}

type PostgresEntityStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresEntityStore) ListEntities(ctx context.Context, userID uuid.UUID) ([]domain.Entity, error) {
	rows, err := s.pool.Query(ctx, `
		select id, user_id, name, type, resource_key, x, y, width, height, sprite_gid, state, metadata, created_at, updated_at
		from user_entities
		where user_id = $1
		order by created_at, id
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

func (s *PostgresEntityStore) CreateEntity(ctx context.Context, entity domain.Entity) (domain.Entity, error) {
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

	err = s.pool.QueryRow(ctx, `
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

func (s *PostgresEntityStore) SaveEntity(ctx context.Context, entity domain.Entity) (domain.Entity, error) {
	if entity.Metadata == nil {
		entity.Metadata = map[string]any{}
	}
	metadata, err := json.Marshal(entity.Metadata)
	if err != nil {
		return domain.Entity{}, err
	}

	err = s.pool.QueryRow(ctx, `
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

func (s *PostgresEntityStore) DeleteEntity(ctx context.Context, userID uuid.UUID, entityID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		delete from user_entities
		where id = $1 and user_id = $2
	`, entityID, userID)
	return err
}

type PostgresPlayerStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresPlayerStore) GetPlayer(ctx context.Context, userID uuid.UUID) (domain.Player, error) {
	var player domain.Player
	var movement []byte
	err := s.pool.QueryRow(ctx, `
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

func (s *PostgresPlayerStore) CreatePlayer(ctx context.Context, player domain.Player) (domain.Player, error) {
	movement, err := encodeMovement(player.Movement)
	if err != nil {
		return domain.Player{}, err
	}
	err = s.pool.QueryRow(ctx, `
		insert into players (user_id, x, y, movement)
		values ($1, $2, $3, $4)
		returning created_at, updated_at
	`, player.UserID, player.X, player.Y, movement).Scan(&player.CreatedAt, &player.UpdatedAt)
	return player, err
}

func (s *PostgresPlayerStore) SavePlayer(ctx context.Context, player domain.Player) (domain.Player, error) {
	movement, err := encodeMovement(player.Movement)
	if err != nil {
		return domain.Player{}, err
	}
	err = s.pool.QueryRow(ctx, `
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

func encodeMovement(movement *domain.PlayerMovement) ([]byte, error) {
	if movement == nil {
		return nil, nil
	}
	return json.Marshal(movement)
}

func decodeMovement(payload []byte) *domain.PlayerMovement {
	if len(payload) == 0 {
		return nil
	}
	var movement domain.PlayerMovement
	if err := json.Unmarshal(payload, &movement); err != nil {
		return nil
	}
	return &movement
}

type PostgresInventoryStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresInventoryStore) ListInventory(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error) {
	rows, err := s.pool.Query(ctx, `
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

func (s *PostgresInventoryStore) AddInventoryItem(ctx context.Context, userID uuid.UUID, itemKey string, quantity int64) (int64, error) {
	if quantity <= 0 {
		return 0, nil
	}

	var before int64
	var after int64
	err := s.pool.QueryRow(ctx, `
		with existing as (
			select quantity
			from player_inventory
			where user_id = $1 and item_key = $2
		), upsert as (
			insert into player_inventory (user_id, item_key, quantity)
			values ($1, $2, least($3, $4))
			on conflict (user_id, item_key) do update set
				quantity = case
					when player_inventory.quantity >= $3 then player_inventory.quantity
					else least($3, player_inventory.quantity + excluded.quantity)
				end,
				updated_at = case
					when player_inventory.quantity < $3 and least($3, player_inventory.quantity + excluded.quantity) <> player_inventory.quantity then now()
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

type PostgresBankStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresBankStore) ListBank(ctx context.Context, userID uuid.UUID) ([]domain.InventoryItem, error) {
	rows, err := s.pool.Query(ctx, `
		select user_id, item_key, quantity, updated_at
		from player_bank
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

func (s *PostgresBankStore) DepositInventoryItem(ctx context.Context, userID uuid.UUID, itemKey string, quantity int64) (int64, error) {
	if quantity <= 0 {
		return 0, nil
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	var current int64
	err = tx.QueryRow(ctx, `
		select quantity
		from player_inventory
		where user_id = $1 and item_key = $2
		for update
	`, userID, itemKey).Scan(&current)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}

	moved := quantity
	if current < moved {
		moved = current
	}
	if moved <= 0 {
		return 0, nil
	}

	remaining := current - moved
	if remaining > 0 {
		if _, err := tx.Exec(ctx, `
			update player_inventory
			set quantity = $3, updated_at = now()
			where user_id = $1 and item_key = $2
		`, userID, itemKey, remaining); err != nil {
			return 0, err
		}
	} else {
		if _, err := tx.Exec(ctx, `
			delete from player_inventory
			where user_id = $1 and item_key = $2
		`, userID, itemKey); err != nil {
			return 0, err
		}
	}

	if _, err := tx.Exec(ctx, `
		insert into player_bank (user_id, item_key, quantity)
		values ($1, $2, $3)
		on conflict (user_id, item_key) do update set
			quantity = player_bank.quantity + excluded.quantity,
			updated_at = now()
	`, userID, itemKey, moved); err != nil {
		return 0, err
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return moved, nil
}

type PostgresSkillStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresSkillStore) ListSkills(ctx context.Context, userID uuid.UUID) ([]domain.PlayerSkill, error) {
	rows, err := s.pool.Query(ctx, `
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

func (s *PostgresSkillStore) AddXP(ctx context.Context, userID uuid.UUID, skillKey string, xp int64) (domain.PlayerSkill, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return domain.PlayerSkill{}, err
	}
	defer tx.Rollback(ctx)

	var skill domain.PlayerSkill
	err = tx.QueryRow(ctx, `
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
	err = tx.QueryRow(ctx, `
		update player_skills
		set level = $3, updated_at = now()
		where user_id = $1 and skill_key = $2
		returning updated_at
	`, userID, skillKey, skill.Level).Scan(&skill.UpdatedAt)
	if err != nil {
		return domain.PlayerSkill{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PlayerSkill{}, err
	}
	return skill, nil
}

func skillLevelForXP(xp int64) int {
	level := 1
	for xp >= xpRequiredForLevel(level+1) {
		level++
	}
	return level
}

func xpRequiredForLevel(level int) int64 {
	if level <= 1 {
		return 0
	}
	return int64(level*level*100 - 100)
}

type PostgresActionStore struct {
	pool *pgxpool.Pool
}

func (s *PostgresActionStore) GetActiveAction(ctx context.Context, userID uuid.UUID) (*domain.PlayerAction, error) {
	var action domain.PlayerAction
	var entityID *uuid.UUID
	var metadata []byte
	err := s.pool.QueryRow(ctx, `
		select id, user_id, type, entity_id, status, started_at, ends_at, next_tick_at, tick_interval_ms, metadata, created_at, updated_at
		from player_actions
		where user_id = $1 and status = 'active'
		order by started_at desc
		limit 1
	`, userID).Scan(
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

func (s *PostgresActionStore) CreateAction(ctx context.Context, action domain.PlayerAction) (domain.PlayerAction, error) {
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

	err = s.pool.QueryRow(ctx, `
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

func (s *PostgresActionStore) SaveAction(ctx context.Context, action domain.PlayerAction) (domain.PlayerAction, error) {
	if action.Metadata == nil {
		action.Metadata = map[string]any{}
	}
	metadata, err := json.Marshal(action.Metadata)
	if err != nil {
		return domain.PlayerAction{}, err
	}

	err = s.pool.QueryRow(ctx, `
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
