# Frontend

Flutter starter app with Riverpod state management, Dio networking, secure token storage, go_router routing, local cache abstraction, and a minimal Flame rendering layer.

## Setup

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=WEBSOCKET_BASE_URL=ws://localhost:8080
```

## iPhone Wireless Testing

For a real iPhone on the same Wi-Fi network as your Mac, do not use `localhost`. The phone needs your Mac's LAN IP.

From the repo root:

```sh
make ios-device-list
make print-host-ip
IOS_DEVICE_NAME="Charles’s iPhone" make ios-device-run
```

You can also use `IOS_DEVICE_ID=<flutter-device-id>` instead of `IOS_DEVICE_NAME`.

This target:

- starts the local backend with Docker Compose
- uses your Mac's detected LAN IP for `API_BASE_URL` and `WEBSOCKET_BASE_URL`
- runs the Flutter app on the selected physical device

Before the first wireless run, pair the phone in Xcode:

1. Connect the iPhone once with USB.
2. Open Xcode and enable the device for development.
3. In Xcode's Devices and Simulators window, enable network connection for the device.
4. Make sure the iPhone and Mac stay on the same Wi-Fi network.

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
