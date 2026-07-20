#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

flutter build web "$@"
mkdir -p "$ROOT_DIR/build/native/web"
(
  cd "$ROOT_DIR/native/crocbridge"
  CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
    -o "$ROOT_DIR/build/native/web/crocbridge-web" ./cmd/crocbridge-web
)

printf 'Built web app and bridge. Run:\n  %s --web-root %s\n' \
  "$ROOT_DIR/build/native/web/crocbridge-web" "$ROOT_DIR/build/web"
