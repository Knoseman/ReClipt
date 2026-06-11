#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ReClipt.xcodeproj"
SCHEME="ReClipt"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/ReClipt.app"
DEVELOPER_DIR_OUTPUT="$(xcode-select -p 2>/dev/null || true)"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found: $PROJECT_PATH" >&2
  exit 1
fi

if [[ -z "$DEVELOPER_DIR_OUTPUT" ]]; then
  echo "xcode-select is not configured." >&2
  exit 1
fi

if [[ "$DEVELOPER_DIR_OUTPUT" == "/Library/Developer/CommandLineTools" ]]; then
  echo "xcodebuild is pointing at Command Line Tools, not full Xcode." >&2
  echo "Run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

echo "Building scheme '$SCHEME' in configuration '$CONFIGURATION'..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build completed, but app bundle was not found at:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

echo
echo "Build succeeded."
echo "App bundle:"
echo "  $APP_PATH"
echo "Executable:"
echo "  $APP_PATH/Contents/MacOS/ReClipt"
