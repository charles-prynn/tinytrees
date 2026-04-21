# Backend

Generic Go API starter using chi, pgx, Postgres, JWT sessions, structured logs, and versioned routes.

## Setup

```sh
cp .env.example .env
go mod tidy
make run
```

The API listens on `:8080` by default.

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
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `GET /v1/me`
- `GET /v1/bootstrap`
- `GET /v1/state`
- `POST /v1/state/sync`

All API responses use a consistent envelope:

```json
{ "data": {}, "error": null, "request_id": "..." }
```
