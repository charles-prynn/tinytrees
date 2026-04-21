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
`/health` health check and restart policy.

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

## Run migrations

Run migrations after creating Postgres and before relying on the API:

```sh
DATABASE_URL='postgres://...' make migrate-prod
```

Use the externally reachable Railway Postgres connection string when running
this from your machine. Railway documents external PostgreSQL access through its
TCP proxy, which is enabled by default.

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
