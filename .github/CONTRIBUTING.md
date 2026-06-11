# Contributing To ReClipt

## Development Setup

- Use macOS 26 or later.
- Use Xcode 26.5 or later.
- Open `ReClipt.xcodeproj`.
- Build the `ReClipt` scheme.

For local ad-hoc builds, update `Configurations/CodeSigning.xcconfig` to include
`Configurations/CodeSigning-AdHoc.xcconfig`.

## Code

- Keep changes focused.
- Prefer existing AppKit and repository patterns.
- Add or update tests when changing model, repository, or service behavior.
- Keep clipboard contents local unless a future change explicitly documents a
  user-controlled network feature.

## Localization

Primary localization content lives in:

- `ReClipt/Resources/Localizable.xcstrings`

When adding or changing user-facing strings, update the string catalog in the
same change.

## Validation

Before opening a change, run the app test scheme in Xcode when available. If a
full Xcode install is not available, at least run local Swift parsing or
typechecking for the files you changed.
