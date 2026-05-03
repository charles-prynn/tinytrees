# Railway Admin Deployment

This admin app deploys to Railway as a static site served by Caddy.

## Create the service

1. Add a new GitHub-backed Railway service for this repository.
2. Set the service root directory to `/admin`.
3. Set the config file path to `/admin/railway.toml`.
4. Generate a public Railway domain for the admin service.

Railway will detect `admin/Dockerfile`, build the static admin app image, and
serve it from Caddy on Railway's `PORT`.

## Service variables

This service does not require build-time variables.

At runtime, the admin UI asks for:

- API base URL
- admin shared secret

The shared secret must match the backend service's `ADMIN_SECRET`.

## Smoke test

After deploy:

1. Open the admin Railway domain.
2. Enter the API base URL for the deployed backend.
3. Enter the backend's `ADMIN_SECRET`.
4. Confirm the overview loads and user actions work.
