#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "[build_ios] Running flutter pub get"
flutter pub get

echo "[build_ios] Building release IPA (no codesign)"
flutter build ipa \
  --release \
  --no-codesign

echo "[build_ios] IPA ready at build/ios/ipa/"
