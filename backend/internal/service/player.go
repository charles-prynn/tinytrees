package service

import (
	"container/heap"
	"context"
	"errors"
	"math"
	"time"

	"starter/backend/internal/domain"
	"starter/backend/internal/store"

	"github.com/google/uuid"
)

const defaultPlayerSpeedTilesPerSecond = 2.0

var ErrInvalidMoveTarget = errors.New("move target is not walkable")

type PlayerService struct {
	players  store.PlayerStore
	maps     store.MapStore
	entities store.EntityStore
	skills   store.SkillStore
	actions  *ActionService
	now      func() time.Time
}

func NewPlayerService(players store.PlayerStore, maps store.MapStore, entities store.EntityStore, skills store.SkillStore) *PlayerService {
	return &PlayerService{
		players:  players,
		maps:     maps,
		entities: entities,
		skills:   skills,
		now:      func() time.Time { return time.Now().UTC() },
	}
}

func (s *PlayerService) SetActionService(actions *ActionService) {
	s.actions = actions
}

func (s *PlayerService) Get(ctx context.Context, userID uuid.UUID) (domain.Player, error) {
	lifecycle, err := s.resolveLifecycle(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	lifecycle.player.Action = lifecycle.action
	return s.attachSkills(ctx, userID, lifecycle.player)
}

func (s *PlayerService) Move(ctx context.Context, userID uuid.UUID, targetX int, targetY int) (domain.Player, error) {
	lifecycle, err := s.resolveLifecycle(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	if lifecycle.state == playerStateHarvesting && s.actions != nil {
		if err := s.actions.CancelActive(ctx, userID); err != nil {
			return domain.Player{}, err
		}
		lifecycle.action = nil
		lifecycle.state = playerStateIdle
	}

	tileMap, err := s.maps.GetTileMap(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	entities, err := s.loadEntities(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	blockedTiles := blockedEntityTiles(entities)

	target := domain.Point{X: targetX, Y: targetY}
	if !isWalkable(tileMap, blockedTiles, target) {
		return domain.Player{}, ErrInvalidMoveTarget
	}

	now := s.now()
	player := lifecycle.player
	from := currentPlayerPoint(player, now)
	delete(blockedTiles, from)
	path := fastestPath(tileMap, blockedTiles, from, target)
	if len(path) <= 1 {
		player.X = targetX
		player.Y = targetY
		player.Movement = nil
		saved, err := s.players.SavePlayer(ctx, player)
		if err != nil {
			return domain.Player{}, err
		}
		return s.attachSkills(ctx, userID, saved)
	}

	duration := time.Duration(math.Round(pathDistance(path) / defaultPlayerSpeedTilesPerSecond * float64(time.Second)))
	player.X = from.X
	player.Y = from.Y
	player.Movement = &domain.PlayerMovement{
		FromX:               from.X,
		FromY:               from.Y,
		TargetX:             targetX,
		TargetY:             targetY,
		Path:                path,
		StartedAt:           now,
		ArrivesAt:           now.Add(duration),
		SpeedTilesPerSecond: defaultPlayerSpeedTilesPerSecond,
	}
	saved, err := s.players.SavePlayer(ctx, player)
	if err != nil {
		return domain.Player{}, err
	}
	return s.attachSkills(ctx, userID, saved)
}

func (s *PlayerService) attachActiveAction(ctx context.Context, userID uuid.UUID, player domain.Player) (domain.Player, error) {
	if s.actions == nil {
		return s.attachSkills(ctx, userID, player)
	}
	action, err := s.actions.Resolve(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	player.Action = action
	return s.attachSkills(ctx, userID, player)
}

func (s *PlayerService) attachSkills(ctx context.Context, userID uuid.UUID, player domain.Player) (domain.Player, error) {
	if s.skills == nil {
		return player, nil
	}
	skills, err := s.skills.ListSkills(ctx, userID)
	if err != nil {
		return domain.Player{}, err
	}
	player.Skills = skills
	return player, nil
}

func (s *PlayerService) loadEntities(ctx context.Context, userID uuid.UUID) ([]domain.Entity, error) {
	entities, err := s.entities.ListEntities(ctx, userID)
	if err != nil {
		return nil, err
	}
	if len(entities) > 0 {
		return entities, nil
	}

	entity, err := s.entities.CreateEntity(ctx, defaultResourceEntity(userID))
	if err != nil {
		return nil, err
	}
	return []domain.Entity{entity}, nil
}

func (s *PlayerService) resolveCompletedMovement(ctx context.Context, player domain.Player) (domain.Player, error) {
	movement := player.Movement
	if movement == nil || s.now().Before(movement.ArrivesAt) {
		return player, nil
	}

	player.X = movement.TargetX
	player.Y = movement.TargetY
	player.Movement = nil
	return s.players.SavePlayer(ctx, player)
}

func defaultPlayer(userID uuid.UUID) domain.Player {
	return domain.Player{
		UserID: userID,
		X:      16,
		Y:      8,
	}
}

func currentPlayerPoint(player domain.Player, now time.Time) domain.Point {
	movement := player.Movement
	if movement == nil || len(movement.Path) == 0 {
		return domain.Point{X: player.X, Y: player.Y}
	}
	if !now.Before(movement.ArrivesAt) {
		return domain.Point{X: movement.TargetX, Y: movement.TargetY}
	}
	if !now.After(movement.StartedAt) {
		return movement.Path[0]
	}

	distance := now.Sub(movement.StartedAt).Seconds() * movement.SpeedTilesPerSecond
	for i := 0; i < len(movement.Path)-1; i++ {
		cost := stepCost(movement.Path[i], movement.Path[i+1])
		if distance <= cost {
			return movement.Path[i]
		}
		distance -= cost
	}
	return movement.Path[len(movement.Path)-1]
}

func fastestPath(tileMap domain.TileMap, blockedTiles map[domain.Point]struct{}, from domain.Point, target domain.Point) []domain.Point {
	if from == target {
		return []domain.Point{from}
	}

	open := &pathPriorityQueue{}
	heap.Init(open)
	heap.Push(open, &pathNode{point: from, priority: heuristic(from, target)})

	cameFrom := map[domain.Point]domain.Point{}
	costSoFar := map[domain.Point]float64{from: 0}

	for open.Len() > 0 {
		current := heap.Pop(open).(*pathNode).point
		if current == target {
			return reconstructPath(cameFrom, from, target)
		}

		for _, next := range neighbors(tileMap, blockedTiles, current) {
			newCost := costSoFar[current] + stepCost(current, next)
			knownCost, seen := costSoFar[next]
			if seen && newCost >= knownCost {
				continue
			}

			costSoFar[next] = newCost
			cameFrom[next] = current
			heap.Push(open, &pathNode{
				point:    next,
				priority: newCost + heuristic(next, target),
			})
		}
	}

	return []domain.Point{from}
}

func neighbors(tileMap domain.TileMap, blockedTiles map[domain.Point]struct{}, point domain.Point) []domain.Point {
	directions := []domain.Point{
		{X: -1, Y: -1}, {X: 0, Y: -1}, {X: 1, Y: -1},
		{X: -1, Y: 0}, {X: 1, Y: 0},
		{X: -1, Y: 1}, {X: 0, Y: 1}, {X: 1, Y: 1},
	}

	result := make([]domain.Point, 0, len(directions))
	for _, direction := range directions {
		next := domain.Point{X: point.X + direction.X, Y: point.Y + direction.Y}
		if !isWalkable(tileMap, blockedTiles, next) {
			continue
		}
		if direction.X != 0 && direction.Y != 0 && cutsBlockedCorner(tileMap, blockedTiles, point, direction) {
			continue
		}
		result = append(result, next)
	}
	return result
}

func isWalkable(tileMap domain.TileMap, blockedTiles map[domain.Point]struct{}, point domain.Point) bool {
	if point.X < 0 || point.Y < 0 || point.X >= tileMap.Width || point.Y >= tileMap.Height {
		return false
	}
	if _, blocked := blockedTiles[point]; blocked {
		return false
	}
	index := point.Y*tileMap.Width + point.X
	return index >= 0 && index < len(tileMap.Tiles) && tileMap.Tiles[index] > 0
}

func cutsBlockedCorner(tileMap domain.TileMap, blockedTiles map[domain.Point]struct{}, point domain.Point, direction domain.Point) bool {
	horizontal := domain.Point{X: point.X + direction.X, Y: point.Y}
	vertical := domain.Point{X: point.X, Y: point.Y + direction.Y}
	return !isWalkable(tileMap, blockedTiles, horizontal) || !isWalkable(tileMap, blockedTiles, vertical)
}

func blockedEntityTiles(entities []domain.Entity) map[domain.Point]struct{} {
	blocked := map[domain.Point]struct{}{}
	for _, entity := range entities {
		if !entityBlocksMovement(entity) {
			continue
		}

		width := max(1, entity.Width)
		height := max(1, entity.Height)
		for y := entity.Y; y < entity.Y+height; y++ {
			for x := entity.X; x < entity.X+width; x++ {
				blocked[domain.Point{X: x, Y: y}] = struct{}{}
			}
		}
	}
	return blocked
}

func entityBlocksMovement(entity domain.Entity) bool {
	return entity.Type == "resource" && entity.State != "depleted"
}

func reconstructPath(cameFrom map[domain.Point]domain.Point, from domain.Point, target domain.Point) []domain.Point {
	path := []domain.Point{target}
	current := target
	for current != from {
		previous, ok := cameFrom[current]
		if !ok {
			return []domain.Point{from}
		}
		current = previous
		path = append(path, current)
	}

	for left, right := 0, len(path)-1; left < right; left, right = left+1, right-1 {
		path[left], path[right] = path[right], path[left]
	}
	return path
}

func pathDistance(path []domain.Point) float64 {
	distance := 0.0
	for i := 0; i < len(path)-1; i++ {
		distance += stepCost(path[i], path[i+1])
	}
	return distance
}

func heuristic(from domain.Point, target domain.Point) float64 {
	dx := math.Abs(float64(from.X - target.X))
	dy := math.Abs(float64(from.Y - target.Y))
	diagonal := math.Min(dx, dy)
	straight := math.Max(dx, dy) - diagonal
	return diagonal*math.Sqrt2 + straight
}

func stepCost(from domain.Point, to domain.Point) float64 {
	dx := math.Abs(float64(from.X - to.X))
	dy := math.Abs(float64(from.Y - to.Y))
	if dx == 1 && dy == 1 {
		return math.Sqrt2
	}
	return math.Max(dx, dy)
}

type pathNode struct {
	point    domain.Point
	priority float64
	index    int
}

type pathPriorityQueue []*pathNode

func (q pathPriorityQueue) Len() int {
	return len(q)
}

func (q pathPriorityQueue) Less(i int, j int) bool {
	return q[i].priority < q[j].priority
}

func (q pathPriorityQueue) Swap(i int, j int) {
	q[i], q[j] = q[j], q[i]
	q[i].index = i
	q[j].index = j
}

func (q *pathPriorityQueue) Push(item any) {
	node := item.(*pathNode)
	node.index = len(*q)
	*q = append(*q, node)
}

func (q *pathPriorityQueue) Pop() any {
	old := *q
	node := old[len(old)-1]
	old[len(old)-1] = nil
	*q = old[:len(old)-1]
	return node
}
