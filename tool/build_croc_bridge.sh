#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOMOBILE_VERSION="v0.0.0-20260709172247-6129f5bee9d5"

export PATH="$(go env GOPATH)/bin:${PATH}"

go install "golang.org/x/mobile/cmd/gomobile@${GOMOBILE_VERSION}"
gomobile init
mkdir -p "${ROOT}/android/app/libs"
cd "${ROOT}/native/crocbridge"
gomobile bind \
  -target=android \
  -androidapi=23 \
  -javapkg=dev.sarrietav \
  -o "${ROOT}/android/app/libs/crocbridge.aar" \
  .
