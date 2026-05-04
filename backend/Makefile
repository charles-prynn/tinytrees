-include .env
export

.PHONY: run run-worker dev test migrate-up migrate-down tidy

run:
	go run ./cmd/api

run-worker:
	go run ./cmd/worker

dev:
	docker compose up --build

test:
	go test ./...

tidy:
	go mod tidy

migrate-up:
	./scripts/migrate.sh up

migrate-down:
	./scripts/migrate.sh down
