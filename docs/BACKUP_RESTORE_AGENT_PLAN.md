# Local Backup/Restore Multi-Agent Plan

## Coordinator Role

The coordinator owns cross-agent decisions, merge order, and collision control. Do
not let feature agents change shared contracts without posting the change here
first.

Coordinator responsibilities:

- Create or approve shared API contracts before agent work starts.
- Own `ReClipt.xcodeproj/project.pbxproj` edits unless a task says otherwise.
- Resolve conflicts in `PreferencesWindowController.swift`, `Constants.swift`,
  `Localizable.xcstrings`, and repository protocols.
- Run `./scripts/validate.sh` after merging all surfaces.
- Keep the app local-only. No cloud, account, telemetry, or external service.

## Product Scope

Add local backup/restore as a user-triggered feature.

Backup should create one local file chosen by the user. Restore should read one
local file chosen by the user.

Initial format:

- Extension: `.recliptbackup`
- Encoding: JSON
- Top-level document fields:
  - `format`: `reclipt-backup`
  - `version`: `1`
  - `appVersion`
  - `exportedAt` as ISO-8601
  - `settings` optional
  - `snippets` optional
  - `history` optional
- Restore mode for v1: merge by default. Do not delete existing user data.
- Clipboard history restore is optional in the UI because it can contain private
  content and large binary pasteboard data.

Hard safety rule: no overwrite/delete/reset of existing snippets, settings, or
history unless the user explicitly confirms that mode and tests cover it. For
v1, avoid destructive restore modes.

## Shared Contracts

Agents should build against these names unless the coordinator changes them.

```swift
enum BackupSection: String, Codable, CaseIterable {
    case settings
    case snippets
    case history
}

struct BackupDocument: Codable, Equatable {
    var format: String
    var version: Int
    var appVersion: String
    var exportedAt: Date
    var settings: BackupSettings?
    var snippets: [SnippetTransferFolder]?
    var history: [BackupHistoryItem]?
}

struct BackupSettings: Codable, Equatable {
    var bools: [String: Bool]
    var integers: [String: Int]
    var strings: [String: String]
    var stringArrays: [String: [String]]
    var excludedApplications: [BackupExcludedApplication]
}

struct BackupExcludedApplication: Codable, Equatable {
    var identifier: String
    var name: String
}

struct BackupHistoryItem: Codable, Equatable {
    var id: String
    var title: String
    var pasteboardTypes: [String]
    var updateAt: Int
    var deviceID: String?
    var assets: [BackupHistoryAsset]
    var thumbnail: BackupHistoryThumbnail?
}

struct BackupHistoryAsset: Codable, Equatable {
    var index: Int
    var pasteboardType: String
    var data: Data
}

struct BackupHistoryThumbnail: Codable, Equatable {
    var kind: String
    var data: Data
}
```

Service contract:

```swift
final class BackupService {
    func exportBackup(to url: URL, sections: Set<BackupSection>) throws
    func previewBackup(at url: URL) throws -> BackupPreview
    func restoreBackup(from url: URL, sections: Set<BackupSection>) throws
}
```

`BackupPreview` should contain counts and metadata only, not full binary data.

## Surface 1: Backup Format + Export Service

### Assignment

Build the format, encoding/decoding, settings export, snippet export adapter, and
backup export service.

### Owns

- New files under `ReClipt/Sources/Backup/`
- New tests under `ReCliptTests/Backup/`
- May read `SnippetTransfer.swift`, `SnippetRepository.swift`, and `Constants.swift`
- Ask coordinator before editing existing repository protocols

### Do not touch

- Preferences UI
- Restore mutation logic in repositories
- Release scripts

### Tasks

1. Add `BackupDocument`, section enums, preview model, and JSON encoder/decoder.
2. Add a settings whitelist using existing `Constants.UserDefaults` keys.
3. Export excluded applications as portable JSON, not keyed archive blobs.
4. Export snippets using existing `SnippetTransferFolder` structure.
5. Export history through read APIs from Surface 2. If Surface 2 is not ready,
   add temporary protocol-based stubs and mark TODOs clearly.
6. Add tests for:
   - JSON round-trip with all sections
   - settings whitelist export
   - excluded app export
   - snippets export preserves title/content/index/enabled
   - missing optional sections decode correctly
   - invalid `format` or unsupported `version` fails

### Acceptance

- Backup files contain no absolute local database path.
- Backup files are deterministic enough for tests by injecting `Date` and
  `appVersion`.
- Unit tests pass for format/export without launching the app.

## Surface 2: Restore + Repository Read/Write APIs

### Assignment

Create safe repository APIs needed by backup export and merge restore.

### Owns

- `ReClipt/Sources/Repositories/PasteboardHistoryRepository.swift`
- `ReClipt/Sources/Repositories/SnippetRepository.swift`
- Repository tests under `ReCliptTests/Repositories/`
- May add focused helpers under `ReClipt/Sources/Backup/` after coordinating
  with Surface 1

### Do not touch

- Preferences UI
- `Localizable.xcstrings`
- Publish/release scripts

### Tasks

1. Add snippet export API if needed:
   - `fetchTransferFolders() -> [SnippetTransferFolder]`
2. Add history export API:
   - fetch all histories in stable order with full assets and thumbnails
   - support paging internally to avoid huge memory spikes if practical
3. Add non-destructive history import API:
   - upsert by history `id`
   - preserve `updateAt`, pasteboard types, assets, and thumbnail
   - keep FTS triggers working
4. Add settings restore helper if not handled by Surface 1:
   - restore only whitelisted keys
   - restore excluded applications by rebuilding `ReCliptAppInfo` archive
5. Add tests for:
   - history export includes assets and thumbnail
   - history restore re-creates content
   - restore updates an existing history with the same id instead of duplicating
   - snippet merge import preserves indexes/enabled state
   - settings restore ignores unknown keys
   - notifications are posted after restore mutations

### Acceptance

- Existing data is not deleted.
- Restore is transactional per section where possible.
- Existing repository tests still pass.

## Surface 3: Preferences UI + User Flow

### Assignment

Add user-facing backup/restore controls in Preferences and wire dialogs/alerts to
`BackupService`.

### Owns

- `ReClipt/Sources/Preferences/PreferencesWindowController.swift`
- UI tests under `ReCliptTests/Preferences/`
- `ReClipt/Resources/Localizable.xcstrings`
- README/docs user-facing text after the core flow stabilizes

### Do not touch

- Repository SQL
- Backup JSON model fields without coordinator approval
- Release scripts

### Tasks

1. Add a new Preferences pane named `Backup` with an SF Symbol such as
   `externaldrive` or `arrow.trianglehead.2.clockwise`.
2. Add export controls:
   - checkboxes: Settings, Snippets, Clipboard history
   - history checkbox must explain that clipboard history can contain private
     content
   - Save panel writes `.recliptbackup`
3. Add restore controls:
   - Open panel selects `.recliptbackup`
   - show preview counts before restore
   - section checkboxes default to sections present in the file
   - confirm before restoring clipboard history
4. Display success/failure alerts.
5. Notify app services after restore so menus refresh.
6. Add tests for:
   - Backup pane appears in toolbar
   - controls exist and default states are safe
   - export action passes selected sections to injected service
   - restore preview and confirmation flow can be tested with fake service

### Acceptance

- ReClipt still does not appear in the Dock.
- Backup/restore is fully local file picker based.
- UI does not block with large history backups more than necessary.

## Collision Rules

1. Start with coordinator scaffolding shared files and project membership before
   feature agents branch.
2. Only the coordinator edits `ReClipt.xcodeproj/project.pbxproj` during active
   parallel work.
3. If an agent needs a new file not pre-scaffolded, add it but do not edit the
   Xcode project. Tell the coordinator the path.
4. Agents should not reformat whole files.
5. Agents must not change backup JSON field names without coordinator approval.
6. Agents should run focused tests for their surface. Coordinator runs full
   validation after merge.

## Merge Order

1. Surface 1 format/contracts.
2. Surface 2 repository APIs and restore implementation.
3. Surface 3 UI integration.
4. Coordinator final pass:
   - resolve strings and docs
   - run `./scripts/validate.sh`
   - update `MEMORY.md` with final decisions

## Ready-to-Paste Agent Briefs

### Agent A Brief

You are Surface 1 for ReClipt local backup/restore. Read `AGENTS.md` and
`docs/BACKUP_RESTORE_AGENT_PLAN.md`. Implement backup JSON format, preview model,
settings export, snippets export adapter, and export service tests. Own only
`ReClipt/Sources/Backup/` and `ReCliptTests/Backup/` unless the coordinator
approves more. Do not edit UI or repository SQL. Follow the shared contracts in
the plan.

### Agent B Brief

You are Surface 2 for ReClipt local backup/restore. Read `AGENTS.md` and
`docs/BACKUP_RESTORE_AGENT_PLAN.md`. Implement safe repository export/import APIs
for snippets and clipboard history, plus settings restore if needed. Own
`PasteboardHistoryRepository.swift`, `SnippetRepository.swift`, and repository
tests. Do not edit UI or localization. Restore must be non-destructive merge by
default.

### Agent C Brief

You are Surface 3 for ReClipt local backup/restore. Read `AGENTS.md` and
`docs/BACKUP_RESTORE_AGENT_PLAN.md`. Add a Backup Preferences pane with local
file export/restore flows using `BackupService`. Own Preferences UI, preference
UI tests, localization, and user docs. Do not edit repository SQL or backup JSON
schema without coordinator approval.
