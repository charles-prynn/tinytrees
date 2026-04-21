#!/usr/bin/env sh
set -eu

direction="${1:-up}"

if ! command -v migrate >/dev/null 2>&1; then
  echo "golang-migrate CLI is required: https://github.com/golang-migrate/migrate"
  exit 1
fi

: "${DATABASE_URL:?DATABASE_URL is required}"

migrate -path migrations -database "$DATABASE_URL" "$direction"
