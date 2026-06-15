//
//  BackupServiceTests.swift
//
//  ReCliptTests
//
//  Created by ReClipt on 2026/06/15.
//

import Foundation
import Testing
@testable import ReClipt

@Suite(.serialized)
struct BackupServiceTests {
    @Test
    func jsonRoundTripsWithAllSections() throws {
        let document = sampleDocument()

        let data = try BackupJSON.encode(document)
        let decoded = try BackupJSON.decode(data)

        #expect(decoded == document)
    }

    @Test
    func missingOptionalSectionsDecodeCorrectly() throws {
        let json = """
        {
          "format": "reclipt-backup",
          "version": 1,
          "appVersion": "1.2.3",
          "exportedAt": "2026-06-15T12:30:00Z"
        }
        """

        let document = try BackupJSON.decode(Data(json.utf8))
        let preview = BackupPreview(document: document)

        #expect(document.settings == nil)
        #expect(document.snippets == nil)
        #expect(document.history == nil)
        #expect(preview.sections.isEmpty)
    }

    @Test
    func invalidFormatOrUnsupportedVersionFails() {
        let invalidFormat = """
        {
          "format": "other",
          "version": 1,
          "appVersion": "1.2.3",
          "exportedAt": "2026-06-15T12:30:00Z"
        }
        """
        let unsupportedVersion = """
        {
          "format": "reclipt-backup",
          "version": 2,
          "appVersion": "1.2.3",
          "exportedAt": "2026-06-15T12:30:00Z"
        }
        """

        #expect(throws: (any Error).self) {
            try BackupJSON.decode(Data(invalidFormat.utf8))
        }
        #expect(throws: (any Error).self) {
            try BackupJSON.decode(Data(unsupportedVersion.utf8))
        }
    }

    @Test
    func settingsWhitelistExportsPortableValues() throws {
        let defaults = try makeDefaults("SettingsWhitelistExportsPortableValues")
        defer { removeDefaults(defaults, suiteName: "SettingsWhitelistExportsPortableValues") }

        defaults.set(true, forKey: Constants.UserDefaults.inputPasteCommand)
        defaults.set(false, forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        defaults.set(42, forKey: Constants.UserDefaults.maxHistorySize)
        defaults.set("not exported", forKey: "unknown.absolute.path")
        defaults.set([
            "public.utf8-plain-text": NSNumber(value: true),
            "public.png": NSNumber(value: false),
            "public.tiff": NSNumber(value: true)
        ], forKey: Constants.UserDefaults.storeTypes)

        let settings = BackupSettingsExporter(defaults: defaults).exportSettings()

        #expect(settings.bools[Constants.UserDefaults.inputPasteCommand] == true)
        #expect(settings.bools[Constants.UserDefaults.reorderClipsAfterPasting] == false)
        #expect(settings.integers[Constants.UserDefaults.maxHistorySize] == 42)
        #expect(settings.strings["unknown.absolute.path"] == nil)
        #expect(settings.stringArrays[Constants.UserDefaults.storeTypes] == ["public.tiff", "public.utf8-plain-text"])
    }

    @Test
    func excludedApplicationsExportAsPortableJSON() throws {
        let defaults = try makeDefaults("ExcludedApplicationsExportAsPortableJSON")
        defer { removeDefaults(defaults, suiteName: "ExcludedApplicationsExportAsPortableJSON") }
        let appInfo = try makeAppInfo(identifier: "com.example.mail", name: "Mail")
        defaults.set([appInfo].archive(), forKey: Constants.UserDefaults.excludeApplications)

        let service = makeService(defaults: defaults, sections: [.settings])
        let url = temporaryBackupURL("excluded-apps")
        defer { try? FileManager.default.removeItem(at: url) }

        try service.exportBackup(to: url, sections: [.settings])
        let data = try Data(contentsOf: url)
        let document = try BackupJSON.decode(data)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(document.settings?.excludedApplications == [BackupExcludedApplication(identifier: "com.example.mail", name: "Mail")])
        #expect(json.contains("com.example.mail"))
        #expect(json.contains("Mail"))
        #expect(!json.contains("NS.objects"))
        #expect(!json.contains("ReCliptAppInfo"))
    }

    @Test
    func snippetsExportPreservesTitleContentIndexAndEnabled() throws {
        let folderID = UUID()
        let snippetID = UUID()
        let folders = [
            SnippetTransferFolder(
                id: folderID,
                title: "Common",
                index: 7,
                isEnabled: false,
                snippets: [
                    SnippetTransferSnippet(
                        id: snippetID,
                        title: "Email",
                        content: "hello@example.com",
                        index: 3,
                        isEnabled: false
                    )
                ]
            )
        ]
        let service = makeService(snippets: folders)
        let url = temporaryBackupURL("snippets")
        defer { try? FileManager.default.removeItem(at: url) }

        try service.exportBackup(to: url, sections: [.snippets])
        let document = try BackupJSON.decode(Data(contentsOf: url))

        #expect(document.snippets == folders)
        #expect(document.settings == nil)
        #expect(document.history == nil)
    }

    @Test
    func exportIsDeterministicWithInjectedDateAndAppVersion() throws {
        let service = makeService(sections: [.settings, .snippets, .history])
        let url = temporaryBackupURL("deterministic")
        defer { try? FileManager.default.removeItem(at: url) }

        try service.exportBackup(to: url, sections: [.settings, .snippets, .history])
        let json = try #require(String(data: Data(contentsOf: url), encoding: .utf8))

        #expect(json.contains("2026-06-15T12:30:00Z"))
        #expect(json.contains("9.9.9-test"))
        #expect(!json.contains(FileManager.default.homeDirectoryForCurrentUser.path))
    }

    @Test
    func previewContainsMetadataAndCountsOnly() throws {
        let service = makeService(sections: [.settings, .snippets, .history])
        let url = temporaryBackupURL("preview")
        defer { try? FileManager.default.removeItem(at: url) }

        try service.exportBackup(to: url, sections: [.settings, .snippets, .history])
        let preview = try service.previewBackup(at: url)

        #expect(preview.appVersion == "9.9.9-test")
        #expect(preview.exportedAt == fixedDate)
        #expect(preview.sections == [.settings, .snippets, .history])
        #expect(preview.snippetFolderCount == 1)
        #expect(preview.snippetCount == 1)
        #expect(preview.historyItemCount == 1)
        #expect(preview.historyAssetCount == 1)
        #expect(preview.historyThumbnailCount == 1)
    }
}

private extension BackupServiceTests {
    var fixedDate: Date { Date(timeIntervalSince1970: 1_781_526_600) }

    func sampleDocument() -> BackupDocument {
        BackupDocument(
            appVersion: "9.9.9-test",
            exportedAt: fixedDate,
            settings: BackupSettings(
                bools: [Constants.UserDefaults.inputPasteCommand: true],
                integers: [Constants.UserDefaults.maxHistorySize: 30],
                strings: [:],
                stringArrays: [Constants.UserDefaults.storeTypes: ["public.utf8-plain-text"]],
                excludedApplications: [BackupExcludedApplication(identifier: "com.example.app", name: "Example")]
            ),
            snippets: [sampleSnippetFolder()],
            history: [sampleHistoryItem()]
        )
    }

    func sampleSnippetFolder() -> SnippetTransferFolder {
        SnippetTransferFolder(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            title: "Common",
            index: 0,
            isEnabled: true,
            snippets: [
                SnippetTransferSnippet(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
                    title: "Email",
                    content: "hello@example.com",
                    index: 0,
                    isEnabled: true
                )
            ]
        )
    }

    func sampleHistoryItem() -> BackupHistoryItem {
        BackupHistoryItem(
            id: "history-1",
            title: "Hello",
            pasteboardTypes: ["public.utf8-plain-text"],
            updateAt: 123,
            deviceID: "device-1",
            assets: [BackupHistoryAsset(index: 0, pasteboardType: "public.utf8-plain-text", data: Data("Hello".utf8))],
            thumbnail: BackupHistoryThumbnail(kind: "image", data: Data([1, 2, 3]))
        )
    }

    func makeService(
        defaults: UserDefaults? = nil,
        snippets: [SnippetTransferFolder]? = nil,
        history: [BackupHistoryItem]? = nil,
        sections: Set<BackupSection> = []
    ) -> BackupService {
        let suiteDefaults = defaults ?? (try? makeDefaults("BackupServiceTests-defaults-\(UUID().uuidString)")) ?? .standard
        if sections.contains(.settings) || defaults != nil {
            suiteDefaults.set(true, forKey: Constants.UserDefaults.inputPasteCommand)
        }
        return BackupService(
            settingsExporter: BackupSettingsExporter(defaults: suiteDefaults),
            snippetExporter: FakeSnippetExporter(folders: snippets ?? [sampleSnippetFolder()]),
            historyExporter: FakeHistoryExporter(items: history ?? [sampleHistoryItem()]),
            dateProvider: { fixedDate },
            appVersionProvider: { "9.9.9-test" }
        )
    }

    func makeDefaults(_ suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func removeDefaults(_ defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func makeAppInfo(identifier: String, name: String) throws -> ReCliptAppInfo {
        try #require(ReCliptAppInfo(info: [
            kCFBundleIdentifierKey as String: identifier as NSString,
            kCFBundleNameKey as String: name as NSString
        ]))
    }

    func temporaryBackupURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
            .appendingPathExtension("recliptbackup")
    }
}

private struct FakeSnippetExporter: BackupSnippetExporting {
    let folders: [SnippetTransferFolder]

    func fetchTransferFolders() -> [SnippetTransferFolder] {
        folders
    }
}

private struct FakeHistoryExporter: BackupHistoryExporting {
    let items: [BackupHistoryItem]

    func fetchBackupHistoryItems() throws -> [BackupHistoryItem] {
        items
    }
}
