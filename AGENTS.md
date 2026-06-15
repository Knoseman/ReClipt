# AGENTS.md

## Purpose

This file gives coding agents the durable project rules for ReClipt. Use
`MEMORY.md` for current session state and recent decisions, but keep durable
workflow, validation, and project constraints here.

## Project Overview

ReClipt is a local-only macOS menu bar clipboard history and snippets app. It
uses local SQLite storage and programmatic AppKit UI. It must not require an
account, backend service, telemetry service, CloudKit, or multi-device sync
unless the user explicitly reopens that decision.

The current distribution path is a self-signed/ad-hoc GitHub Release. The app is
not Developer ID signed or notarized unless the project direction changes.

## Non-Negotiables

- ReClipt must never appear in the Dock. It is a menu bar app.
- Keep the app local-only. Do not add CloudKit, sync, account login, telemetry,
  analytics, or external storage.
- Do not overwrite, delete, migrate, or reset user clipboard/snippet data unless
  the task explicitly requires it and the migration is tested.
- Always quit and restart ReClipt between manual app test builds. Accessibility
  trust and paste behavior are tied to the running app bundle/signature.
- Committing code does not update the downloadable app. Users get the app from
  the latest GitHub Release asset.
- `MEMORY.md` is gitignored local project memory. Read it when resuming work,
  update it when state/roadmap decisions change, but do not commit it.

## Validation Commands

Run this before committing source, test, script, or project changes:

```bash
./scripts/validate.sh
```

This validates shell scripts, runs the full test suite, builds a disposable
unsigned Release app under `build/Validation`, and verifies the app binary.

For a signed local Release build used in manual Accessibility testing:

```bash
./scripts/build-release.sh
```

For app-level smoke checks after a Release build:

```bash
./scripts/smoke-app.sh
SMOKE_UI_FLOW=1 ./scripts/smoke-app.sh
```

For self-signed release validation:

```bash
./scripts/validate-self-signed-release.sh
```

This runs full validation, builds the ad-hoc release zip, runs UI smoke against
the Release bundle, and verifies the checksum.

## Release Workflow

Self-signed releases are published through GitHub Releases. The release assets
are:

- `ReClipt-macOS.zip`
- `ReClipt-macOS.zip.sha256`

To publish a new self-signed release:

```bash
./scripts/bump-version.sh x.y.z
git add "ReClipt/Supporting Files/Info.plist"
git commit -m "Bump version to x.y.z"
git push
./scripts/publish-self-signed-release.sh
```

The publish script validates, builds, packages, verifies the checksum, checks
that the tracked worktree is clean and pushed, creates/pushes the tag, and
uploads release assets.

Use `docs/RELEASE_CHECKLIST.md` for release checks. For small patch releases
where the user has already tested the installed app, a full install rehearsal is
optional; still use the guarded publish script.

## Manual App Checklist

When manually testing `/Applications/ReClipt.app`:

- ReClipt is absent from the Dock.
- Menu bar icon visibility follows `Preferences > General > Menu bar icon style`.
- Clipboard history captures copied text.
- Selecting a history item pastes into the active app when Accessibility is enabled.
- Finder-copied files display useful file names, not only `(Files)`.
- `Show menu item icons` shows meaningful type icons or previews.
- Snippets can be created, edited, deleted, imported, exported, and pasted.
- Preferences panes switch without truncation or toolbar jumping.
- Settings and snippets persist after quit/reopen.
- Accessibility prompts do not loop after ReClipt is enabled and relaunched.

## Coding Guidance

- Prefer existing AppKit/project patterns over introducing new frameworks.
- Add or update tests for model, repository, service, menu, preferences, and
  snippets behavior changes.
- Use SF Symbols for new AppKit icons where possible.
- Keep utility UI compact and practical; do not add marketing/landing screens.
- Keep comments sparse and only where they clarify non-obvious behavior.
- Do not commit build artifacts, `.DS_Store`, `Internal/`, `build/`, or
  `MEMORY.md`.

## Documentation Map

- `README.md`: user/developer overview, build, validation, and release commands.
- `docs/INSTALL_SELF_SIGNED.md`: install instructions for release downloaders.
- `docs/RELEASE_CHECKLIST.md`: release operator checklist.
- `PRIVACY.md`: local-only privacy statement.
- `MEMORY.md`: ignored current-state notes and decisions for future sessions.
