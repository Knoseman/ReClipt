#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCTS_DIR="${PRODUCTS_DIR:-$ROOT_DIR/build/Build/Products/$CONFIGURATION}"
APP_NAME="ReClipt.app"
APP_PATH="$PRODUCTS_DIR/$APP_NAME"
ZIP_PATH="$PRODUCTS_DIR/ReClipt-macOS.zip"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Build the app first with ./scripts/build-release.sh" >&2
  exit 1
fi

rm -f "$ZIP_PATH"

echo "Packaging '$APP_NAME'..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo
echo "Package succeeded."
echo "Archive:"
echo "  $ZIP_PATH"
