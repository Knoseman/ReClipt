#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
APP_PATH="${APP_PATH:-$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/ReClipt.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
BINARY_PATH="$APP_PATH/Contents/MacOS/ReClipt"
EXPECTED_BUNDLE_IDENTIFIER="${EXPECTED_BUNDLE_IDENTIFIER:-com.knoseman.reclipt}"
PROCESS_NAME="${PROCESS_NAME:-ReClipt}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-10}"
SMOKE_LEAVE_RUNNING="${SMOKE_LEAVE_RUNNING:-0}"
launched_app=0

fail() {
  echo "Smoke test failed: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

quit_running_app() {
  if ! pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
    return
  fi

  osascript -e "tell application id \"$EXPECTED_BUNDLE_IDENTIFIER\" to quit" >/dev/null 2>&1 || true

  local attempts=0
  while pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 && (( attempts < 30 )); do
    sleep 0.2
    attempts=$((attempts + 1))
  done

  if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
    pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
  fi

  attempts=0
  while pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 && (( attempts < 30 )); do
    sleep 0.2
    attempts=$((attempts + 1))
  done
}

cleanup() {
  if [[ "$SMOKE_LEAVE_RUNNING" != "1" && "$launched_app" == "1" ]]; then
    quit_running_app
  fi
}

trap cleanup EXIT

[[ -d "$APP_PATH" ]] || fail "app bundle not found at $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "Info.plist not found at $INFO_PLIST"
[[ -x "$BINARY_PATH" ]] || fail "executable not found at $BINARY_PATH"

bundle_identifier="$(plist_value CFBundleIdentifier)"
bundle_name="$(plist_value CFBundleName)"
bundle_package_type="$(plist_value CFBundlePackageType)"
bundle_short_version="$(plist_value CFBundleShortVersionString)"
bundle_version="$(plist_value CFBundleVersion)"
ls_ui_element="$(plist_value LSUIElement)"

[[ "$bundle_identifier" == "$EXPECTED_BUNDLE_IDENTIFIER" ]] || fail "expected bundle identifier $EXPECTED_BUNDLE_IDENTIFIER, found $bundle_identifier"
[[ "$bundle_name" == "ReClipt" ]] || fail "expected bundle name ReClipt, found $bundle_name"
[[ "$bundle_package_type" == "APPL" ]] || fail "expected package type APPL, found $bundle_package_type"
[[ -n "$bundle_short_version" ]] || fail "CFBundleShortVersionString is empty"
[[ -n "$bundle_version" ]] || fail "CFBundleVersion is empty"
[[ "$ls_ui_element" == "true" ]] || fail "LSUIElement must be true so ReClipt stays out of the Dock"

lipo "$BINARY_PATH" -verify_arch arm64 >/dev/null

echo "Quitting any running $PROCESS_NAME instance..."
quit_running_app

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  fail "$PROCESS_NAME is still running before launch"
fi

echo "Launching $APP_PATH..."
open "$APP_PATH"
launched_app=1

pid=""
attempts=0
max_attempts=$((LAUNCH_TIMEOUT_SECONDS * 10))
while [[ -z "$pid" && $attempts -lt $max_attempts ]]; do
  pid="$(pgrep -x "$PROCESS_NAME" | head -n 1 || true)"
  if [[ -n "$pid" ]]; then
    break
  fi
  sleep 0.1
  attempts=$((attempts + 1))
done

[[ -n "$pid" ]] || fail "$PROCESS_NAME did not start within ${LAUNCH_TIMEOUT_SECONDS}s"

sleep 2

if ! ps -p "$pid" >/dev/null 2>&1; then
  fail "$PROCESS_NAME launched and then exited"
fi

echo "Smoke test succeeded."
echo "Process:"
echo "  $PROCESS_NAME ($pid)"
echo "Bundle:"
echo "  $APP_PATH"

if [[ "$SMOKE_LEAVE_RUNNING" == "1" ]]; then
  echo "Leaving app running because SMOKE_LEAVE_RUNNING=1."
else
  echo "Quitting app after smoke test."
fi
