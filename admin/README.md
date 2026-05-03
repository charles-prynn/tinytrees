# Admin App

Standalone admin panel for the woodcutting game.

## Run

From the repository root:

```sh
docker compose up --build
```

Then open:

```text
http://localhost:3001
```

Use:

- API base URL: `http://localhost:8080`
- admin secret: the value of `ADMIN_SECRET`

The panel stores the API base URL locally for convenience. The admin secret is
kept in memory only.

## Actions

- inspect all users and their current player status
- inspect a single user's inventory, skills, and world summary
- grant inventory items
- grant skill XP
- teleport a player to a walkable tile

## Security

The app sends the shared secret in the `X-Admin-Secret` header to the backend's
admin-only endpoints.
