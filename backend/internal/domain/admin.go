package domain

import "time"

type AdminOverview struct {
	GeneratedAt time.Time
	Totals      AdminTotals
	Users       []AdminUserSummary
}

type AdminTotals struct {
	TotalUsers    int
	GuestUsers    int
	LocalUsers    int
	ActivePlayers int
	MovingPlayers int
	IdlePlayers   int
}

type AdminUserSummary struct {
	User              User
	PlayerX           int
	PlayerY           int
	Status            string
	WoodcuttingLevel  int
	WoodcuttingXP     int64
	LastUpdatedAt     time.Time
	CurrentActionType string
}

type AdminUserDetail struct {
	User   User
	Player Player
	Action *PlayerAction
	Skills []PlayerSkill
	Items  []InventoryItem
	World  AdminWorldSummary
}

type AdminWorldSummary struct {
	TotalEntities      int
	ActiveResources    int
	DepletedResources  int
	ResourceCounts     map[string]int
	ResourceStateCount map[string]int
}
