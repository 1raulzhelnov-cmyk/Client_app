#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "[tests] Fetching dependencies"
flutter pub get

echo "[tests] Running analyzer"
flutter analyze

echo "[tests] Running unit and widget tests with coverage"
flutter test --coverage

if command -v genhtml >/dev/null 2>&1; then
  mkdir -p coverage/html
  genhtml coverage/lcov.info --output-directory coverage/html
  echo "[tests] HTML coverage report generated at coverage/html/index.html"
else
  echo "[tests] genhtml not found, skipping HTML report generation"
fi
