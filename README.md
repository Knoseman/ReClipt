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

## Development Notes

- The app stores clipboard history, snippets, and preferences locally.
- The Swift module name is `ReClipt`.
- The app display name is `ReClipt`.
- Tests live in `ReCliptTests`.

## Privacy

See `PRIVACY.md`.

## License

ReClipt is available under the MIT license. See `LICENSE`.
