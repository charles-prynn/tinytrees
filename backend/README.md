# Backend

Generic Go API starter using chi, pgx, Postgres, JWT sessions, structured logs, and versioned routes.

## Setup

```sh
cp .env.example .env
go mod tidy
make run
make run-worker
```

The API listens on `:8080` by default. Run the worker alongside it so actions
continue progressing and event deliveries continue processing while players are
offline.

For local `make run`, the API also starts embedded workers by default so
harvests and inbox delivery work without a second process. Set
`RUN_EMBEDDED_WORKERS=false` when you want the API process to stay passive and
use `make run-worker` or the dedicated worker container instead.

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
- `GET /v1/events/inbox`
- `POST /v1/events/inbox/ack`
- `GET /v1/inventory`
- `GET /v1/bank`
- `POST /v1/bank/deposit`
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
{ "id": "7", "type": "events.inbox" }
{ "id": "8", "type": "events.ack", "payload": { "ids": [101, 102] } }
{ "id": "9", "type": "bank.get" }
{ "id": "10", "type": "bank.deposit", "payload": { "entity_id": "<uuid>", "item_key": "wood", "quantity": 10 } }
```

Server messages include the same `id` so the app can match replies:

```json
{ "id": "3", "type": "player.updated", "data": { "player": {} } }
{ "id": "5", "type": "action.started", "data": { "action": {} } }
{ "id": "6", "type": "inventory.updated", "data": { "items": [] } }
{ "id": "7", "type": "events.updated", "data": { "items": [] } }
{ "id": "8", "type": "events.acked", "data": { "items": [] } }
```

Errors use the same shape as HTTP errors:

```json
{ "id": "3", "type": "player.move.error", "error": { "code": "validation_error", "message": "move target is not walkable" } }
```

## Action Events

Long-running player actions are now resolved by a separate worker process
instead of when a player reads state. The API is passive for action reads;
the worker owns due-action execution and event delivery.

Durable domain events are still recorded internally in Postgres. The client-facing
notification surface is the delivered inbox:

```text
GET /v1/events/inbox?after_id=0&limit=50
Authorization: Bearer <access_token>
```

Inbox items can be acknowledged with:

```text
POST /v1/events/inbox/ack
Authorization: Bearer <access_token>
{ "ids": [101, 102] }
```

The internal event stream includes entries such as:

- `action.started`
- `action.cancelled`
- `action.completed`
- `resource.depleted`
- `skill.level_up`

The inbox is the delivery layer for player notifications. It is what the client
should use for notification-style UI and for polling when no realtime
connection is open. The current inbox implementation only delivers
`action.completed` notifications to avoid noisy start/cancel events.

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
