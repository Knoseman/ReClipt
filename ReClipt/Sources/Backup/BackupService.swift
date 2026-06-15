//
//  BackupService.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/15.
//

import Foundation

final class BackupService {
    private let settingsExporter: BackupSettingsExporter
    private let snippetExporter: BackupSnippetExporting
    private let historyExporter: BackupHistoryExporting
    private let dateProvider: () -> Date
    private let appVersionProvider: () -> String

    init(
        settingsExporter: BackupSettingsExporter = BackupSettingsExporter(),
        snippetExporter: BackupSnippetExporting = SnippetRepositoryBackupExporter(),
        historyExporter: BackupHistoryExporting = PasteboardHistoryRepositoryBackupExporter(),
        dateProvider: @escaping () -> Date = Date.init,
        appVersionProvider: @escaping () -> String = { Bundle.main.appVersion ?? "unknown" }
    ) {
        self.settingsExporter = settingsExporter
        self.snippetExporter = snippetExporter
        self.historyExporter = historyExporter
        self.dateProvider = dateProvider
        self.appVersionProvider = appVersionProvider
    }

    func exportBackup(to url: URL, sections: Set<BackupSection>) throws {
        let document = try makeDocument(sections: sections)
        let data = try BackupJSON.encode(document)
        try data.write(to: url, options: [.atomic])
    }

    func previewBackup(at url: URL) throws -> BackupPreview {
        let data = try Data(contentsOf: url)
        let document = try BackupJSON.decode(data)
        return BackupPreview(document: document)
    }

    func restoreBackup(from url: URL, sections: Set<BackupSection>) throws {
        let data = try Data(contentsOf: url)
        let document = try BackupJSON.decode(data)

        if sections.contains(.settings), let settings = document.settings {
            BackupSettingsRestoreHelper.restore(settings)
        }
        if sections.contains(.snippets), let snippets = document.snippets {
            _ = try SnippetRepository().restoreTransferFolders(snippets)
        }
        if sections.contains(.history), let history = document.history {
            try PasteboardHistoryRepository().restoreBackupHistoryItems(history)
        }
    }

    private func makeDocument(sections: Set<BackupSection>) throws -> BackupDocument {
        BackupDocument(
            appVersion: appVersionProvider(),
            exportedAt: dateProvider(),
            settings: sections.contains(.settings) ? settingsExporter.exportSettings() : nil,
            snippets: sections.contains(.snippets) ? snippetExporter.fetchTransferFolders() : nil,
            history: sections.contains(.history) ? try historyExporter.fetchBackupHistoryItems() : nil
        )
    }
}
