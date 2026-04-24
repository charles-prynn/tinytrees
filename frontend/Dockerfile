FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter config --enable-web && flutter pub get

COPY . .

ARG API_BASE_URL
ARG WEBSOCKET_BASE_URL
ARG DEBUG_FPS=false

RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=WEBSOCKET_BASE_URL=${WEBSOCKET_BASE_URL} \
    --dart-define=DEBUG_FPS=${DEBUG_FPS}

FROM caddy:2.8-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/build/web /srv
