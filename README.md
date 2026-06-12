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

## Development Notes

- The app stores clipboard history, snippets, and preferences locally.
- The Swift module name is `ReClipt`.
- The app display name is `ReClipt`.
- Tests live in `ReCliptTests`.

## Privacy

See `PRIVACY.md`.

## License

ReClipt is available under the MIT license. See `LICENSE`.
