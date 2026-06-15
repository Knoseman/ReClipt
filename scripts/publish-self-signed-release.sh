#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/ReClipt/Supporting Files/Info.plist"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build}"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
ZIP_PATH="$PRODUCTS_DIR/ReClipt-macOS.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"
PUBLISH_VALIDATE="${PUBLISH_VALIDATE:-1}"
PUBLISH_DRY_RUN="${PUBLISH_DRY_RUN:-0}"

cd "$ROOT_DIR"

fail() {
  echo "Publish failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_command gh
require_command git
require_command shasum
require_command awk

remote_tag_commit_sha() {
  local tag="$1"
  local lines peeled_sha tag_sha

  lines="$(git ls-remote --tags origin "refs/tags/$tag" "refs/tags/$tag^{}")"
  [[ -n "$lines" ]] || return 0

  peeled_sha="$(printf "%s\n" "$lines" | awk -v ref="refs/tags/$tag^{}" '$2 == ref { print $1; exit }')"
  if [[ -n "$peeled_sha" ]]; then
    printf "%s" "$peeled_sha"
    return 0
  fi

  tag_sha="$(printf "%s\n" "$lines" | awk -v ref="refs/tags/$tag" '$2 == ref { print $1; exit }')"
  printf "%s" "$tag_sha"
}

[[ -f "$INFO_PLIST" ]] || fail "Info.plist not found: $INFO_PLIST"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
[[ -n "$VERSION" ]] || fail "CFBundleShortVersionString is empty"

TAG="${RELEASE_TAG:-v$VERSION}"
RELEASE_TITLE="${RELEASE_TITLE:-ReClipt $VERSION}"

if [[ "$PUBLISH_VALIDATE" == "1" ]]; then
  ./scripts/validate-self-signed-release.sh
fi

[[ -s "$ZIP_PATH" ]] || fail "release zip not found or empty: $ZIP_PATH"
[[ -s "$CHECKSUM_PATH" ]] || fail "checksum file not found or empty: $CHECKSUM_PATH"

(
  cd "$PRODUCTS_DIR"
  shasum -a 256 -c "$(basename "$CHECKSUM_PATH")" >/dev/null
) || fail "checksum verification failed"

if [[ -n "$(git status --short --untracked-files=no)" ]]; then
  fail "tracked worktree changes exist; commit or discard them before publishing"
fi

CURRENT_SHA="$(git rev-parse HEAD)"
UPSTREAM_REF="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[[ -n "$UPSTREAM_REF" ]] || fail "current branch has no upstream"

UPSTREAM_SHA="$(git rev-parse '@{u}')"
[[ "$CURRENT_SHA" == "$UPSTREAM_SHA" ]] || fail "HEAD does not match upstream $UPSTREAM_REF; push first"

REMOTE_TAG_SHA="$(remote_tag_commit_sha "$TAG")"
TAG_NEEDS_PUSH=0

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  TAG_SHA="$(git rev-list -n 1 "$TAG")"
  [[ "$TAG_SHA" == "$CURRENT_SHA" ]] || fail "local tag $TAG points at $TAG_SHA, not HEAD $CURRENT_SHA; bump Info.plist or set RELEASE_TAG before publishing a new release"
  if [[ -n "$REMOTE_TAG_SHA" ]]; then
    [[ "$REMOTE_TAG_SHA" == "$CURRENT_SHA" ]] || fail "remote tag $TAG points at $REMOTE_TAG_SHA, not HEAD $CURRENT_SHA; bump Info.plist or set RELEASE_TAG before publishing a new release"
  else
    TAG_NEEDS_PUSH=1
  fi
elif [[ -n "$REMOTE_TAG_SHA" ]]; then
  [[ "$REMOTE_TAG_SHA" == "$CURRENT_SHA" ]] || fail "remote tag $TAG points at $REMOTE_TAG_SHA, not HEAD $CURRENT_SHA; bump Info.plist or set RELEASE_TAG before publishing a new release"
  echo "Remote tag $TAG already points at HEAD."
else
  echo "Creating local tag $TAG at $CURRENT_SHA..."
  if [[ "$PUBLISH_DRY_RUN" == "0" ]]; then
    git tag -a "$TAG" -m "ReClipt $VERSION"
  fi
  TAG_NEEDS_PUSH=1
fi

if [[ "$PUBLISH_DRY_RUN" == "1" ]]; then
  echo "Dry run succeeded."
  echo "Would publish:"
  echo "  Tag: $TAG"
  echo "  Title: $RELEASE_TITLE"
  echo "  Zip: $ZIP_PATH"
  echo "  Checksum: $CHECKSUM_PATH"
  exit 0
fi

if [[ "$TAG_NEEDS_PUSH" == "1" ]]; then
  git push origin "$TAG"
fi

NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/reclipt-release-notes.XXXXXX")"
trap 'rm -f "$NOTES_FILE"' EXIT

{
  echo "Self-signed ad-hoc macOS release for ReClipt $VERSION."
  echo
  echo "This build is not Apple-notarized. macOS Gatekeeper may warn or block it on first launch."
  echo
  echo "Install guide:"
  echo "https://github.com/Knoseman/ReClipt/blob/$TAG/docs/INSTALL_SELF_SIGNED.md"
  echo
  echo "Verify the download with:"
  echo
  echo '```bash'
  echo 'shasum -a 256 -c ReClipt-macOS.zip.sha256'
  echo '```'
  echo
  echo "If right-click > Open does not work after copying the app to /Applications, remove quarantine with:"
  echo
  echo '```bash'
  echo 'xattr -dr com.apple.quarantine /Applications/ReClipt.app'
  echo '```'
  echo
  echo "ReClipt is a menu bar app and does not appear in the Dock. Enable it in System Settings > Privacy & Security > Accessibility if paste from history or snippets does not work, then quit and reopen ReClipt."
} > "$NOTES_FILE"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG already exists; uploading assets with --clobber..."
  gh release upload "$TAG" "$ZIP_PATH" "$CHECKSUM_PATH" --clobber
else
  echo "Creating GitHub Release $TAG..."
  gh release create "$TAG" "$ZIP_PATH" "$CHECKSUM_PATH" \
    --title "$RELEASE_TITLE" \
    --notes-file "$NOTES_FILE"
fi

echo
echo "Published self-signed release:"
echo "  $TAG"
