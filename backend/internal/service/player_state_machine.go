package service

import (
	"context"
	"errors"
	"time"

	"starter/backend/internal/domain"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type playerLifecycleState string

const (
	playerStateIdle       playerLifecycleState = "idle"
	playerStateMoving     playerLifecycleState = "moving"
	playerStateHarvesting playerLifecycleState = "harvesting"
)

type resolvedPlayerLifecycle struct {
	player domain.Player
	action *domain.PlayerAction
	state  playerLifecycleState
}

func (s *PlayerService) resolveLifecycle(ctx context.Context, userID uuid.UUID) (resolvedPlayerLifecycle, error) {
	player, err := s.players.GetPlayer(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		player, err = s.players.CreatePlayer(ctx, defaultPlayer(userID))
	}
	if err != nil {
		return resolvedPlayerLifecycle{}, err
	}

	player, err = s.resolveCompletedMovement(ctx, player)
	if err != nil {
		return resolvedPlayerLifecycle{}, err
	}

	var action *domain.PlayerAction
	if s.actions != nil {
		action, err = s.actions.Resolve(ctx, userID)
		if err != nil {
			return resolvedPlayerLifecycle{}, err
		}
	}

	state := classifyPlayerLifecycle(player, action, s.now())
	return resolvedPlayerLifecycle{
		player: player,
		action: action,
		state:  state,
	}, nil
}

func classifyPlayerLifecycle(player domain.Player, action *domain.PlayerAction, now time.Time) playerLifecycleState {
	if action != nil {
		return playerStateHarvesting
	}
	if movement := player.Movement; movement != nil && now.Before(movement.ArrivesAt) {
		return playerStateMoving
	}
	return playerStateIdle
}
