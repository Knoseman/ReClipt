#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ReClipt.xcodeproj"
SCHEME="ReClipt"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/ReClipt.app"
ZIP_PATH="$PRODUCTS_DIR/ReClipt-macOS.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"
DEVELOPER_DIR_OUTPUT="$(xcode-select -p 2>/dev/null || true)"
RELEASE_CLEAN="${RELEASE_CLEAN:-1}"

typeset -a XCODEBUILD_ACTION_PREFIX

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

if [[ "$RELEASE_CLEAN" == "1" ]]; then
  XCODEBUILD_ACTION_PREFIX+=(clean)
fi

echo "Building ad-hoc signed release..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_HARDENED_RUNTIME=YES \
  "${XCODEBUILD_ACTION_PREFIX[@]}" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build completed, but app bundle was not found at:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

echo
echo "Verifying ad-hoc signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,36p'

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"

echo
echo "Packaging '$APP_PATH'..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo
echo "Writing SHA-256 checksum..."
(
  cd "$PRODUCTS_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo
echo "Gatekeeper assessment, expected to reject ad-hoc builds:"
spctl -a -vv "$APP_PATH" 2>&1 || true

echo
echo "Ad-hoc release package:"
echo "  $ZIP_PATH"
echo "Checksum:"
echo "  $CHECKSUM_PATH"
echo
echo "Note: this build is not notarized. Users may need to right-click Open,"
echo "or remove quarantine with:"
echo "  xattr -dr com.apple.quarantine /Applications/ReClipt.app"
