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

type PlayerEventDelivery struct {
	ID          int64      `json:"id"`
	EventID     int64      `json:"event_id"`
	UserID      uuid.UUID  `json:"user_id"`
	Destination string     `json:"destination"`
	Status      string     `json:"status"`
	AvailableAt time.Time  `json:"available_at"`
	DeliveredAt *time.Time `json:"delivered_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

type PlayerInboxItem struct {
	ID            int64          `json:"id"`
	UserID        uuid.UUID      `json:"user_id"`
	EventID       int64          `json:"event_id"`
	AggregateType string         `json:"aggregate_type"`
	AggregateID   *uuid.UUID     `json:"aggregate_id,omitempty"`
	EventType     string         `json:"event_type"`
	Status        string         `json:"status"`
	Payload       map[string]any `json:"payload"`
	DeliveredAt   time.Time      `json:"delivered_at"`
	ReadAt        *time.Time     `json:"read_at,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
}
