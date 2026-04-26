API_BASE_URL ?= http://localhost:$(PORT)
WEBSOCKET_BASE_URL ?= ws://localhost:$(PORT)
PORT?=8080
SCHEME?=http
HOST_IP ?= $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)
DEVICE_API_BASE_URL ?= $(SCHEME)://$(HOST_IP):$(PORT)
DEVICE_WEBSOCKET_BASE_URL ?= wss://$(HOST_IP):$(PORT)
DATABASE_URL ?= postgres://app:app@localhost:5432/app?sslmode=disable
ACCESS_TOKEN_SECRET ?= change-me-access
REFRESH_TOKEN_SECRET ?= change-me-refresh
ACCESS_TOKEN_TTL ?= 15m
REFRESH_TOKEN_TTL ?= 720h
ALLOWED_ORIGINS ?= http://localhost:3000,http://localhost:$(PORT)
FLUTTER_RUN_ARGS ?=
DEBUG_FPS ?= false
IOS_SIMULATOR ?= iPhone 17
IOS_DEVICE_ID ?=
IOS_DEVICE_NAME ?=
IOS_RUN_DIR ?= /tmp/woodcutting-game-ios-run
IOS_FLUTTER_CONFIG_HOME ?= /tmp/woodcutting-game-flutter-config
IOS_FLUTTER_BUILD_DIR ?= ../../../../../tmp/woodcutting-game-flutter-build

.PHONY: help run frontend web ios-flutter-config ios-clean-xattrs ios-sim-open ios-sim-boot ios-sim-sync ios-sim-build ios-sim-run ios-sim-list ios-device-list ios-device-run print-host-ip backend backend-local backend-up backend-down db-up db-down migrate-up migrate-down migrate-prod dev test clean

help:
	@echo "Targets:"
	@echo "  make run            Start backend with Docker Compose, then run Flutter"
	@echo "  make frontend       Run the Flutter app"
	@echo "  make web            Start backend and run Flutter in Chrome"
	@echo "  make web DEBUG_FPS=true Run Flutter web with an FPS counter"
	@echo "  make ios-flutter-config Configure iOS builds to write outside Documents"
	@echo "  make ios-clean-xattrs Clear macOS extended attributes from iOS build artifacts"
	@echo "  make ios-sim-run    Boot an iOS simulator and run the Flutter app"
	@echo "  make ios-sim-build  Build the Flutter app for iOS simulator"
	@echo "  make ios-sim-boot   Boot the configured iOS simulator"
	@echo "  make ios-sim-open   Open Simulator.app"
	@echo "  make ios-sim-list   List available iOS simulators"
	@echo "  make ios-device-list List Flutter-visible physical/wireless Apple devices"
	@echo "  make ios-device-run Run the Flutter app on a physical iPhone over USB or Wi-Fi"
	@echo "  make print-host-ip  Show the Mac IP address used for device builds"
	@echo "  make backend        Run API + Postgres with Docker Compose"
	@echo "  make backend-local  Run the Go API locally against localhost Postgres"
	@echo "  make backend-up     Start API + Postgres in the background"
	@echo "  make backend-down   Stop Docker Compose services"
	@echo "  make db-up          Start only Postgres"
	@echo "  make db-down        Stop only Postgres"
	@echo "  make migrate-up     Run database migrations with Docker Compose"
	@echo "  make migrate-down   Roll back one database migration with Docker Compose"
	@echo "  make migrate-prod   Run database migrations against DATABASE_URL"
	@echo "  make dev            Alias for backend"
	@echo "  make test           Run backend and frontend tests"
	@echo "  make clean          Clean Flutter build output"

run: backend-up frontend

frontend:
	cd frontend && flutter run --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS) $(FLUTTER_RUN_ARGS)

web: backend-up
	cd frontend && flutter run -d chrome --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS) $(FLUTTER_RUN_ARGS)

ios-flutter-config:
	@mkdir -p "$(IOS_FLUTTER_CONFIG_HOME)"
	@printf '{\n  "build-dir": "$(IOS_FLUTTER_BUILD_DIR)"\n}\n' > "$(IOS_FLUTTER_CONFIG_HOME)/settings"
	@mkdir -p /tmp/woodcutting-game-flutter-build

ios-clean-xattrs:
	@xattr -cr frontend/build/ios frontend/ios 2>/dev/null || true
	@xattr -dr com.apple.FinderInfo frontend/build/ios frontend/ios 2>/dev/null || true
	@xattr -dr 'com.apple.fileprovider.fpfs#P' frontend/build/ios frontend/ios 2>/dev/null || true

ios-sim-open:
	open -a Simulator

ios-sim-list:
	xcrun simctl list devices available

ios-device-list:
	cd frontend && flutter devices

print-host-ip:
	@echo $(HOST_IP)

ios-sim-boot: ios-sim-open
	@if [ -n "$(IOS_DEVICE_ID)" ]; then \
		xcrun simctl boot "$(IOS_DEVICE_ID)" || true; \
	else \
		xcrun simctl boot "$(IOS_SIMULATOR)" || true; \
	fi
	@xcrun simctl bootstatus booted -b

ios-sim-sync:
	mkdir -p "$(IOS_RUN_DIR)"
	rsync -a --delete \
		--exclude build \
		--exclude .dart_tool \
		--exclude ios/Pods \
		--exclude ios/.symlinks \
		frontend/ "$(IOS_RUN_DIR)/frontend/"

ios-sim-build: ios-flutter-config ios-clean-xattrs ios-sim-sync
	cd "$(IOS_RUN_DIR)/frontend" && XDG_CONFIG_HOME="$(IOS_FLUTTER_CONFIG_HOME)" flutter build ios --simulator --debug --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS)

ios-sim-run: backend-up ios-flutter-config ios-clean-xattrs ios-sim-boot
	@if [ -n "$(IOS_DEVICE_ID)" ]; then \
		cd frontend && XDG_CONFIG_HOME="$(IOS_FLUTTER_CONFIG_HOME)" flutter run -d "$(IOS_DEVICE_ID)" --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS) $(FLUTTER_RUN_ARGS); \
	else \
		cd frontend && XDG_CONFIG_HOME="$(IOS_FLUTTER_CONFIG_HOME)" flutter run -d "$(IOS_SIMULATOR)" --dart-define=API_BASE_URL=$(API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS) $(FLUTTER_RUN_ARGS); \
	fi

ios-device-run: ios-flutter-config ios-clean-xattrs
	@if [ -n "$(IOS_DEVICE_ID)" ]; then \
		cd frontend && XDG_CONFIG_HOME="$(IOS_FLUTTER_CONFIG_HOME)" flutter run -d "$(IOS_DEVICE_ID)" --dart-define=API_BASE_URL=$(DEVICE_API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(DEVICE_WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS) $(FLUTTER_RUN_ARGS); \
	elif [ -n "$(IOS_DEVICE_NAME)" ]; then \
		cd frontend && XDG_CONFIG_HOME="$(IOS_FLUTTER_CONFIG_HOME)" flutter run -d "$(IOS_DEVICE_NAME)" --dart-define=API_BASE_URL=$(DEVICE_API_BASE_URL) --dart-define=WEBSOCKET_BASE_URL=$(DEVICE_WEBSOCKET_BASE_URL) --dart-define=DEBUG_FPS=$(DEBUG_FPS) $(FLUTTER_RUN_ARGS); \
	else \
		echo "Set IOS_DEVICE_ID or IOS_DEVICE_NAME. Use 'make ios-device-list' to discover the device."; \
		exit 1; \
	fi

backend:
	docker compose up --build

backend-local:
	cd backend && \
	DATABASE_URL="$(DATABASE_URL)" \
	ACCESS_TOKEN_SECRET="$(ACCESS_TOKEN_SECRET)" \
	REFRESH_TOKEN_SECRET="$(REFRESH_TOKEN_SECRET)" \
	ACCESS_TOKEN_TTL="$(ACCESS_TOKEN_TTL)" \
	REFRESH_TOKEN_TTL="$(REFRESH_TOKEN_TTL)" \
	ALLOWED_ORIGINS="$(ALLOWED_ORIGINS)" \
	go run ./cmd/api

backend-up:
	docker compose up --build -d postgres api

backend-down:
	docker compose down

db-up:
	docker compose up -d postgres

db-down:
	docker compose stop postgres

migrate-up:
	docker compose run --rm migrate

migrate-down:
	docker compose run --rm migrate -path /migrations -database "postgres://app:app@postgres:5432/app?sslmode=disable" down 1

migrate-prod:
	@if [ "$(origin DATABASE_URL)" = "file" ]; then \
		echo "Set DATABASE_URL explicitly, e.g. DATABASE_URL='postgres://...' make migrate-prod"; \
		exit 1; \
	fi
	docker run --rm \
		-v "$$(pwd)/backend/migrations:/migrations:ro" \
		migrate/migrate:v4.18.3 \
		-path /migrations \
		-database "$(DATABASE_URL)" \
		up

dev: backend

test:
	cd backend && go test ./...
	cd frontend && flutter test

clean:
	cd frontend && flutter clean
