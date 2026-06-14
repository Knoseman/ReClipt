#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ReClipt.xcodeproj"
SCHEME="ReClipt"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/ReClipt.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/ReClipt"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/build/logs}"
TEST_LOG="$LOG_DIR/validate-test.log"
BUILD_LOG="$LOG_DIR/validate-release-build.log"
DEVELOPER_DIR_OUTPUT="$(xcode-select -p 2>/dev/null || true)"
VALIDATE_CLEAN="${VALIDATE_CLEAN:-0}"

typeset -a XCODEBUILD_PACKAGE_ARGS
typeset -a XCODEBUILD_ACTION_PREFIX

if [[ -n "${CLONED_SOURCE_PACKAGES_DIR_PATH:-}" ]]; then
  XCODEBUILD_PACKAGE_ARGS+=(
    -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR_PATH"
  )
fi

if [[ -n "${PACKAGE_CACHE_PATH:-}" ]]; then
  XCODEBUILD_PACKAGE_ARGS+=(
    -packageCachePath "$PACKAGE_CACHE_PATH"
  )
fi

if [[ "$VALIDATE_CLEAN" == "1" ]]; then
  XCODEBUILD_ACTION_PREFIX+=(clean)
fi

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

mkdir -p "$LOG_DIR"

echo "Running full test suite..."
xcodebuild \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -scheme "$SCHEME" \
  -project "$PROJECT_PATH" \
  "${XCODEBUILD_PACKAGE_ARGS[@]}" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  "${XCODEBUILD_ACTION_PREFIX[@]}" \
  test 2>&1 | tee "$TEST_LOG"

echo
echo "Building Release app..."
xcodebuild \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  -scheme "$SCHEME" \
  -project "$PROJECT_PATH" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${XCODEBUILD_PACKAGE_ARGS[@]}" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  "${XCODEBUILD_ACTION_PREFIX[@]}" \
  build 2>&1 | tee "$BUILD_LOG"

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Release executable was not found at:" >&2
  echo "  $BINARY_PATH" >&2
  exit 1
fi

echo
echo "Verifying Apple Silicon binary..."
lipo "$BINARY_PATH" -verify_arch arm64

echo
echo "Validation succeeded."
echo "App bundle:"
echo "  $APP_PATH"
echo "Logs:"
echo "  $TEST_LOG"
echo "  $BUILD_LOG"
