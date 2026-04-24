# Railway Frontend Deployment

This frontend deploys to Railway as a Flutter web app served by Caddy.

## Create the service

1. Add a new GitHub-backed Railway service for this repository.
2. Set the service root directory to `/frontend`.
3. Set the config file path to `/frontend/railway.toml`.
4. Generate a public Railway domain for the frontend service.

Railway will detect `frontend/Dockerfile`, build the Flutter web bundle, and
serve it from Caddy on Railway's `PORT`.

## Service variables

Set these variables on the frontend service:

```sh
API_BASE_URL=https://<api-domain>
WEBSOCKET_BASE_URL=wss://<api-domain>
DEBUG_FPS=false
```

For Railway-to-Railway wiring, use reference variables that point at the API
service's public domain.

These values are build-time inputs for Flutter web, so changing them triggers a
new frontend deploy.

## WebSocket auth

Browser WebSocket clients cannot attach an `Authorization` header during the
connection handshake. This app passes the access token as an `access_token`
query parameter only for the WebSocket connect request. Native Flutter clients
continue to use the same WebSocket base URL without that browser-specific
constraint.

## Smoke test

After deploy:

1. Open the frontend Railway domain.
2. Confirm guest login succeeds.
3. Confirm movement requests reach the API over `wss://.../v1/ws`.
