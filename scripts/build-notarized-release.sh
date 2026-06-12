#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ReClipt.xcodeproj"
SCHEME="ReClipt"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/ReClipt.app"
NOTARY_ZIP_PATH="$PRODUCTS_DIR/ReClipt-notary-upload.zip"
FINAL_ZIP_PATH="$PRODUCTS_DIR/ReClipt-macOS.zip"
TEAM_ID="${TEAM_ID:-894T922935}"
DEVELOPER_ID_IDENTITY="${DEVELOPER_ID_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ReCliptNotaryProfile}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found: $PROJECT_PATH" >&2
  exit 1
fi

DEVELOPER_DIR_OUTPUT="$(xcode-select -p 2>/dev/null || true)"
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

if ! security find-identity -v -p codesigning | grep -q "\"$DEVELOPER_ID_IDENTITY"; then
  echo "Developer ID signing identity not found." >&2
  echo "Expected an identity matching:" >&2
  echo "  $DEVELOPER_ID_IDENTITY" >&2
  echo "Install a Developer ID Application certificate, then retry." >&2
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Notary profile is not configured or could not be validated:" >&2
  echo "  $NOTARY_PROFILE" >&2
  echo "Create it with:" >&2
  echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <apple-id> --team-id $TEAM_ID" >&2
  exit 1
fi

echo "Building Developer ID signed release..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build completed, but app bundle was not found at:" >&2
  echo "  $APP_PATH" >&2
  exit 1
fi

echo
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,40p'

rm -f "$NOTARY_ZIP_PATH" "$FINAL_ZIP_PATH"

echo
echo "Creating notarization upload archive..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP_PATH"

echo
echo "Submitting to Apple notarization service..."
xcrun notarytool submit "$NOTARY_ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo
echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo
echo "Creating final release archive..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP_PATH"

echo
echo "Checking Gatekeeper assessment..."
spctl -a -vv "$APP_PATH"

echo
echo "Notarized release package:"
echo "  $FINAL_ZIP_PATH"
