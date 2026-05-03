# Backend

Generic Go API starter using chi, pgx, Postgres, JWT sessions, structured logs, and versioned routes.

## Setup

```sh
cp .env.example .env
go mod tidy
make run
```

The API listens on `:8080` by default.

Set `ADMIN_SECRET` to enable the standalone admin panel endpoints.

## Docker

From the repository root:

```sh
docker compose up --build
```

## Migrations

This template expects the `golang-migrate` CLI for local migrations.

```sh
make migrate-up
make migrate-down
```

## Endpoints

- `GET /health`
- `POST /v1/auth/guest/login`
- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `POST /v1/auth/guest/upgrade`
- `GET /v1/me`
- `GET /v1/ws`
- `GET /v1/bootstrap`
- `GET /v1/state`
- `POST /v1/state/sync`
- `GET /v1/map`
- `GET /v1/entities`
- `GET /v1/player`
- `POST /v1/player/move`
- `GET /v1/actions/current`
- `POST /v1/actions/harvest`
- `GET /v1/events`
- `GET /v1/inventory`
- `GET /v1/admin/overview`
- `GET /v1/admin/users/{userID}`
- `POST /v1/admin/users/{userID}/inventory`
- `POST /v1/admin/users/{userID}/skills/xp`
- `POST /v1/admin/users/{userID}/position`

All API responses use a consistent envelope:

```json
{ "data": {}, "error": null, "request_id": "..." }
```

## Admin Access

Admin routes are protected by a shared secret sent in the `X-Admin-Secret`
header. They are intentionally separate from the player auth flow.

Example:

```text
X-Admin-Secret: <ADMIN_SECRET>
```

## Realtime

Keep guest login, token refresh, bootstrap, map/entity fetches, and state sync on
HTTP. Use the authenticated WebSocket endpoint for realtime player commands:

```text
GET /v1/ws
Authorization: Bearer <access_token>
```

Client messages:

```json
{ "id": "1", "type": "ping" }
{ "id": "2", "type": "player.get" }
{ "id": "3", "type": "player.move", "payload": { "target_x": 10, "target_y": 12 } }
{ "id": "4", "type": "actions.current" }
{ "id": "5", "type": "actions.harvest", "payload": { "entity_id": "<uuid>" } }
{ "id": "6", "type": "inventory.get" }
```

Server messages include the same `id` so the app can match replies:

```json
{ "id": "3", "type": "player.updated", "data": { "player": {} } }
{ "id": "5", "type": "action.started", "data": { "action": {} } }
{ "id": "6", "type": "inventory.updated", "data": { "items": [] } }
```

Errors use the same shape as HTTP errors:

```json
{ "id": "3", "type": "player.move.error", "error": { "code": "validation_error", "message": "move target is not walkable" } }
```

## Action Events

Long-running player actions are now resolved by a background worker instead of
only when a player reads state. Durable player-scoped events are recorded in the
database and can be fetched with:

```text
GET /v1/events?after_id=0&limit=50
Authorization: Bearer <access_token>
```

The event log includes entries such as:

- `action.started`
- `action.cancelled`
- `action.completed`
- `resource.depleted`
- `skill.level_up`

## Auth Modes

The backend now supports:

- guest login for instant play
- guest account upgrade to email/password
- password login for returning users

Upgrade the current authenticated guest user:

```json
POST /v1/auth/guest/upgrade
{
  "username": "player_one",
  "email": "player@example.com",
  "password": "password123"
}
```

Login with username/password later:

```json
POST /v1/auth/login
{
  "username": "player_one",
  "password": "password123"
}
```
