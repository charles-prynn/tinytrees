package domain

import (
	"time"

	"github.com/google/uuid"
)

type PlayerEvent struct {
	ID            int64          `json:"id"`
	UserID        uuid.UUID      `json:"user_id"`
	AggregateType string         `json:"aggregate_type"`
	AggregateID   *uuid.UUID     `json:"aggregate_id,omitempty"`
	EventType     string         `json:"event_type"`
	Payload       map[string]any `json:"payload"`
	CreatedAt     time.Time      `json:"created_at"`
}
