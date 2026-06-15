//
//  BackupExportAdapters.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/15.
//

import AppKit
import Foundation

protocol BackupSnippetExporting {
    func fetchTransferFolders() -> [SnippetTransferFolder]
}

protocol BackupHistoryExporting {
    func fetchBackupHistoryItems() throws -> [BackupHistoryItem]
}

struct SnippetRepositoryBackupExporter: BackupSnippetExporting {
    let repository: SnippetRepositoryProtocol

    init(repository: SnippetRepositoryProtocol = SnippetRepository()) {
        self.repository = repository
    }

    func fetchTransferFolders() -> [SnippetTransferFolder] {
        repository.fetchFolderDetails().map { detail in
            SnippetTransferFolder(
                id: detail.folder.id,
                title: detail.folder.title,
                index: detail.folder.index,
                isEnabled: detail.folder.isEnabled,
                snippets: detail.snippets.map { snippet in
                    SnippetTransferSnippet(
                        id: snippet.id,
                        title: snippet.title,
                        content: snippet.content,
                        index: snippet.index,
                        isEnabled: snippet.isEnabled
                    )
                }
            )
        }
    }
}

struct PasteboardHistoryRepositoryBackupExporter: BackupHistoryExporting {
    let repository: PasteboardHistoryRepositoryProtocol
    let pageSize: Int

    init(
        repository: PasteboardHistoryRepositoryProtocol = PasteboardHistoryRepository(),
        pageSize: Int = 100
    ) {
        self.repository = repository
        self.pageSize = max(1, pageSize)
    }

    func fetchBackupHistoryItems() throws -> [BackupHistoryItem] {
        var items = [BackupHistoryItem]()
        var offset = 0

        while true {
            let details = repository.fetchHistoryDetails(
                ascending: true,
                includesThumbnailAsset: true,
                limit: pageSize,
                offset: offset
            )
            guard !details.isEmpty else { break }

            for detail in details {
                let content = repository.fetchContent(id: detail.history.id)
                let assets = content?.assets.enumerated().map { index, asset in
                    BackupHistoryAsset(
                        index: index,
                        pasteboardType: asset.type.rawValue,
                        data: asset.data
                    )
                } ?? []
                let thumbnail = detail.thumbnailAsset.map {
                    BackupHistoryThumbnail(kind: $0.kind.rawValue, data: $0.data)
                }

                items.append(BackupHistoryItem(
                    id: detail.history.id,
                    title: detail.history.title,
                    pasteboardTypes: detail.history.pasteboardTypes.map(\.rawValue),
                    updateAt: detail.history.updateAt,
                    deviceID: detail.history.deviceID,
                    assets: assets,
                    thumbnail: thumbnail
                ))
            }

            offset += details.count
        }

        return items
    }
}
