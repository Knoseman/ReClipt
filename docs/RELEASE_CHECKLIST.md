# ReClipt Release Checklist

Use this checklist before publishing a GitHub Release.

## Version

1. Choose the next version number.
2. Bump the app version:

```sh
./scripts/bump-version.sh 1.2.1
```

3. Commit and push the version change.
4. Confirm GitHub CI passes on `main`.

## Automated Validation

Run the full self-signed release gate:

```sh
./scripts/validate-self-signed-release.sh
```

This must pass before publishing. It runs the test suite, builds the release zip, runs the app smoke flow, verifies menu-bar-only behavior, and checks the SHA-256 file.

## Artifact Check

Confirm these files exist:

```text
build/Build/Products/Release/ReClipt-macOS.zip
build/Build/Products/Release/ReClipt-macOS.zip.sha256
```

Verify the checksum from the artifact directory:

```sh
cd build/Build/Products/Release
shasum -a 256 -c ReClipt-macOS.zip.sha256
```

Expected result:

```text
ReClipt-macOS.zip: OK
```

## Manual Install Check

Test the zip the same way a user will:

1. Unzip `ReClipt-macOS.zip`.
2. Move `ReClipt.app` to `/Applications`.
3. Quit any running ReClipt instance.
4. Open `/Applications/ReClipt.app`.
5. If macOS blocks launch, use the self-signed install guide.

Install guide:

```text
docs/INSTALL_SELF_SIGNED.md
```

## Manual App Check

Confirm the app-level behavior that automation cannot fully prove:

1. ReClipt does not appear in the Dock.
2. The menu bar icon appears when the icon style is not Hidden.
3. Preferences opens from the menu.
4. Preferences tabs stay aligned when switching between panes.
5. Changing Preferences settings affects the app.
6. Clipboard history captures newly copied text.
7. Selecting a history item pastes when Accessibility permission is enabled.
8. Selecting a history item copies or fails gracefully when Accessibility permission is not enabled.
9. Snippets Editor opens from the menu.
10. Snippet folders and snippets can be created, renamed, edited, deleted, imported, and exported.
11. Selecting a snippet pastes when Accessibility permission is enabled.
12. Quit and reopen ReClipt, then confirm settings and snippets persist.

## Publish

Run a dry run first:

```sh
PUBLISH_VALIDATE=0 PUBLISH_DRY_RUN=1 ./scripts/publish-self-signed-release.sh
```

Then publish:

```sh
./scripts/publish-self-signed-release.sh
```

After publishing:

1. Open the GitHub Release.
2. Confirm both assets are attached:
   - `ReClipt-macOS.zip`
   - `ReClipt-macOS.zip.sha256`
3. Confirm the release notes include the install guide, checksum command, quarantine workaround, and Accessibility reminder.
