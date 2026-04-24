# Railway Deployment

This backend is ready to deploy to Railway as a Docker service with a Railway
PostgreSQL service.

## Create the services

1. Create a Railway project.
2. Add a PostgreSQL database service.
3. Add a GitHub-backed service for this repository.
4. Set the API service root directory to `/backend`.
5. Set the API service config file path to `/backend/railway.toml`.
6. Generate a public Railway domain for the API service.

Railway will build the API from `backend/Dockerfile`. The Railway config adds a
pre-deploy migration step, a `/health` health check, and restart policy.

## API variables

Set these variables on the API service:

```sh
DATABASE_URL=${{Postgres.DATABASE_URL}}
ACCESS_TOKEN_SECRET=<random-long-secret>
REFRESH_TOKEN_SECRET=<random-long-secret>
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=720h
ALLOWED_ORIGINS=
```

For mobile apps, CORS is not usually involved because they are not browser
origins. If you later add a web client, set `ALLOWED_ORIGINS` to its exact HTTPS
origin.

Generate secrets locally with:

```sh
openssl rand -base64 48
```

## Migrations

API deploys now run migrations automatically in Railway before the new
deployment is started:

```sh
sh -lc '/app/migrate -path /app/migrations -database "$DATABASE_URL" up'
```

This runs as the service's pre-deploy command, so:

1. A failed migration blocks the deploy.
2. The app only starts after migrations succeed.
3. You do not need a separate migration service for normal deploys.

If you need to run migrations manually from your machine, this still works:

```sh
DATABASE_URL='postgres://...' make migrate-prod
```

## Smoke test

After deploy:

```sh
curl https://<your-api-domain>/health
```

The expected response is a successful JSON envelope from the API.

For the Flutter app later, point it at the deployed API:

```sh
flutter run --dart-define=API_BASE_URL=https://<your-api-domain>
```
