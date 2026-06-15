#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/ReClipt/Supporting Files/Info.plist"

fail() {
  echo "Version bump failed: $*" >&2
  exit 1
}

usage() {
  echo "Usage: ./scripts/bump-version.sh <x.y.z>"
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

VERSION="$1"
[[ "$VERSION" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || fail "version must use x.y.z format"
[[ -f "$INFO_PLIST" ]] || fail "Info.plist not found: $INFO_PLIST"

CURRENT_SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
CURRENT_BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

if [[ "$CURRENT_SHORT_VERSION" == "$VERSION" && "$CURRENT_BUILD_VERSION" == "$VERSION" ]]; then
  echo "Version is already $VERSION."
else
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$INFO_PLIST"
fi

TAG="v$VERSION"

echo "Updated app version:"
echo "  CFBundleShortVersionString: $CURRENT_SHORT_VERSION -> $VERSION"
echo "  CFBundleVersion: $CURRENT_BUILD_VERSION -> $VERSION"
echo "  Release tag: $TAG"

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo
  echo "Warning: local tag $TAG already exists. Choose a new version before publishing a new release." >&2
fi
