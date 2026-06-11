//
//  SQLiteDataSchema.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import AppKit
import Foundation

// MARK: - PasteboardHistory

struct PasteboardHistory: Identifiable, Equatable {
    typealias ID = String

    let id: ID
    let title: String
    let pasteboardTypes: [NSPasteboard.PasteboardType]
    let updateAt: Int
    let deviceID: String?

    var primaryType: NSPasteboard.PasteboardType? {
        pasteboardTypes.first
    }
}

// MARK: - PasteboardHistoryAsset

struct PasteboardHistoryAsset: Identifiable, Equatable {
    typealias ID = UUID

    let id: ID
    let pasteboardHistoryID: PasteboardHistory.ID
    let index: Int
    let pasteboardType: NSPasteboard.PasteboardType
    let data: Data
}

// MARK: - PasteboardHistoryThumbnailAsset

struct PasteboardHistoryThumbnailAsset: Identifiable, Equatable {
    let pasteboardHistoryID: PasteboardHistory.ID
    let kind: Kind
    let data: Data
    var id: PasteboardHistory.ID { pasteboardHistoryID }

    enum Kind: String {
        case image
        case colorCode
    }
}

// MARK: - PasteboardHistoryDetail

struct PasteboardHistoryDetail: Equatable {
    let history: PasteboardHistory
    let thumbnailAsset: PasteboardHistoryThumbnailAsset?
}

// MARK: - SnippetFolder

struct SnippetFolder: Identifiable, Equatable {
    typealias ID = UUID

    let id: ID
    let title: String
    let index: Int
    let isEnabled: Bool
}

// MARK: - Snippet

struct Snippet: Identifiable, Equatable {
    typealias ID = UUID

    let id: ID
    let folderID: SnippetFolder.ID
    let title: String
    let content: String
    let index: Int
    let isEnabled: Bool
}

// MARK: - NSPasteboard.PasteboardType Helpers

extension NSPasteboard.PasteboardType {
    static func fromJSON(_ json: String) -> [NSPasteboard.PasteboardType] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array.map { NSPasteboard.PasteboardType($0) }
    }

    static func toJSON(_ types: [NSPasteboard.PasteboardType]) -> String {
        let array = types.map { $0.rawValue }
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
