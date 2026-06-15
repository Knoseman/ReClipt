#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/ReClipt.app"
ZIP_PATH="$PRODUCTS_DIR/ReClipt-macOS.zip"

cd "$ROOT_DIR"

echo "==> Running local validation"
VALIDATE_CLEAN="${VALIDATE_CLEAN:-1}" ./scripts/validate.sh

echo
echo "==> Building ad-hoc release package"
./scripts/build-self-signed-release.sh

echo
echo "==> Running app UI smoke validation"
SMOKE_UI_FLOW=1 ./scripts/smoke-app.sh

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not found:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

if [[ ! -s "$ZIP_PATH" ]]; then
  echo "Expected release zip was not found or is empty:" >&2
  echo "  $ZIP_PATH" >&2
  exit 1
fi

echo
echo "Self-signed release validation succeeded."
echo "App bundle:"
echo "  $APP_PATH"
echo "Release zip:"
echo "  $ZIP_PATH"
