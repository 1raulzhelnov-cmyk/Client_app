#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "[build_android] Running flutter pub get"
flutter pub get

echo "[build_android] Building release APK (arm64)"
flutter build apk \
  --release \
  --target-platform android-arm64 \
  --split-debug-info=build/app/outputs/symbols \
  --obfuscate

echo "[build_android] APK ready at build/app/outputs/flutter-apk/app-release.apk"
