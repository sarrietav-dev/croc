#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$(go env GOOS)}"
ARCH="${2:-$(go env GOARCH)}"

case "${TARGET}" in
  linux)
    OUTPUT="${ROOT}/build/native/linux/crocbridge-helper"
    ;;
  windows)
    OUTPUT="${ROOT}/build/native/windows/crocbridge-helper.exe"
    ;;
  *)
    echo "Unsupported desktop target: ${TARGET}" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "${OUTPUT}")"
cd "${ROOT}/native/crocbridge"
CGO_ENABLED=0 GOOS="${TARGET}" GOARCH="${ARCH}" go build \
  -trimpath \
  -ldflags="-s -w" \
  -o "${OUTPUT}" \
  ./cmd/crocbridge-helper
