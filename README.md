# ReClipt

ReClipt is a macOS clipboard history and snippets app.

The current codebase is being updated around a native macOS app target, local
SQLite storage, programmatic AppKit views, and a simplified dependency surface.

## Requirements

- macOS 26 or later
- Xcode 26.5 or later

## Build

Open `ReClipt.xcodeproj` in Xcode and build the `ReClipt` scheme.

For local ad-hoc builds, update `Configurations/CodeSigning.xcconfig` to include
`Configurations/CodeSigning-AdHoc.xcconfig`.

No external service configuration is required for local builds.

### Command-line build

Run the full local validation pass with:

```bash
./scripts/validate.sh
```

This runs the test suite, builds the Release app, and verifies the app binary is
`arm64`.

This repo includes a local release build script:

```bash
./scripts/build-release.sh
```

Expected output:

```text
build/Build/Products/Release/ReClipt.app
```

The inner executable is:

```text
build/Build/Products/Release/ReClipt.app/Contents/MacOS/ReClipt
```

Notes:
- `xcodebuild` must point to full Xcode, not Command Line Tools only.
- If needed, run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- For local unsigned/ad-hoc builds, enable `Configurations/CodeSigning-AdHoc.xcconfig` from `Configurations/CodeSigning.xcconfig`.
- The current project target is `arm64` only.

### Manual App Validation

After `./scripts/validate.sh` succeeds, launch the built app:

```bash
open build/Build/Products/Release/ReClipt.app
```

For a quick automated app-level smoke test, run:

```bash
./scripts/build-release.sh
./scripts/smoke-app.sh
```

This builds the normal locally signed Release app, verifies the app bundle,
confirms ReClipt is configured as a menu bar app without a Dock icon, checks the
signature, launches it, checks that it remains running briefly, then quits it. It
intentionally quits any already-running ReClipt instance first so each run starts
from a fresh app process. This matters because Accessibility permissions are tied
to the app's signed identity.

Check these app-level behaviors manually:

- ReClipt launches without a Dock icon.
- The menu bar icon appears when the icon style is not Hidden.
- Clipboard history captures new copied text.
- Selecting a history item pastes or copies it according to Accessibility permission state.
- Snippets can be created, edited, imported, exported, and pasted.
- Preferences tabs stay aligned and settings take effect after changing them.

### Ad-hoc Release

The no-subscription release path is an ad-hoc signed zip:

```bash
./scripts/build-self-signed-release.sh
```

Expected output:

```text
build/Build/Products/Release/ReClipt-macOS.zip
```

This build is not notarized by Apple. It is suitable for technical testers, but
macOS Gatekeeper may warn or block it on first launch. If right-click > Open does
not work, users can remove the quarantine flag after copying the app to
`/Applications`:

```bash
xattr -dr com.apple.quarantine /Applications/ReClipt.app
```

### Package

After building, create a distributable zip with:

```bash
./scripts/package-release.sh
```

Expected output:

```text
build/Build/Products/Release/ReClipt-macOS.zip
```

### Notarized Public Release

For a release that other people can download and run normally, use Developer ID
signing and Apple notarization. This requires:

- A `Developer ID Application` certificate in the login keychain.
- A saved notarytool credential profile. The default profile name used by this
  repo is `ReCliptNotaryProfile`.

Create the notary profile once:

```bash
xcrun notarytool store-credentials ReCliptNotaryProfile --apple-id <apple-id> --team-id 894T922935
```

Then build, notarize, staple, and package:

```bash
./scripts/build-notarized-release.sh
```

Expected output:

```text
build/Build/Products/Release/ReClipt-macOS.zip
```

The script fails early if the Developer ID certificate or notary profile is not
available.

## Performance & Optimizations (June 2026)

ReClipt has been optimized for high-performance clipboard handling and low memory footprint:

- **Database**: SQLite with Write-Ahead Logging (WAL) for concurrent operations and asynchronous initialization to ensure a fast app launch.
- **Memory**: Efficient image resizing using `CoreGraphics` and compressed PNG thumbnail storage.
- **Responsiveness**: Lazy-loading history submenus to handle 1000+ items without UI stutter.
- **Native UI**: Transitioned to SF Symbols for a modern, integrated macOS aesthetic.

## Development Notes

- The app stores clipboard history, snippets, and preferences locally in a SQLite database.
- Database migrations and initialization are handled asynchronously.
- The Swift module name is `ReClipt`.
- Tests live in `ReCliptTests`.

## Privacy

See `PRIVACY.md`.

## License

ReClipt is available under the MIT license. See `LICENSE`.
