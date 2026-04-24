# Frontend

Flutter starter app with Riverpod state management, Dio networking, secure token storage, go_router routing, local cache abstraction, and a minimal Flame rendering layer.

## Setup

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=WEBSOCKET_BASE_URL=ws://localhost:8080
```

## Structure

- `lib/app`: application root and theme
- `lib/core`: config, networking, routing, storage, errors, shared API primitives
- `lib/features/auth`: guest auth, token persistence, current user
- `lib/features/bootstrap`: startup configuration fetch
- `lib/features/state`: generic state snapshot loading and sync
- `lib/features/rendering`: Flame rendering layer
- `lib/features/shared`: reusable screens and shell widgets

## Startup Flow

1. Restore tokens from secure storage.
2. Call `GET /v1/me`; if it fails, perform guest login.
3. Fetch bootstrap config.
4. Fetch the generic state snapshot.
5. Enter the main shell with the Flame canvas.

## Notes

- The rendering layer is intentionally generic and contains no domain logic.
- `TokenStorage` and `LocalCache` are interfaces so platform-specific implementations can be swapped later.
- Networking retries a failed authorized request once after refreshing tokens.
