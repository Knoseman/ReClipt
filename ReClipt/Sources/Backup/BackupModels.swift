//
//  BackupModels.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/15.
//

import Foundation

enum BackupSection: String, Codable, CaseIterable {
    case settings
    case snippets
    case history
}

struct BackupDocument: Codable, Equatable {
    static let supportedFormat = "reclipt-backup"
    static let supportedVersion = 1

    var format: String
    var version: Int
    var appVersion: String
    var exportedAt: Date
    var settings: BackupSettings?
    var snippets: [SnippetTransferFolder]?
    var history: [BackupHistoryItem]?

    init(
        format: String = Self.supportedFormat,
        version: Int = Self.supportedVersion,
        appVersion: String,
        exportedAt: Date,
        settings: BackupSettings? = nil,
        snippets: [SnippetTransferFolder]? = nil,
        history: [BackupHistoryItem]? = nil
    ) {
        self.format = format
        self.version = version
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.snippets = snippets
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        guard format == Self.supportedFormat else {
            throw BackupError.invalidFormat(format)
        }

        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.supportedVersion else {
            throw BackupError.unsupportedVersion(version)
        }

        appVersion = try container.decode(String.self, forKey: .appVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        settings = try container.decodeIfPresent(BackupSettings.self, forKey: .settings)
        snippets = try container.decodeIfPresent([SnippetTransferFolder].self, forKey: .snippets)
        history = try container.decodeIfPresent([BackupHistoryItem].self, forKey: .history)
    }
}

struct BackupSettings: Codable, Equatable {
    var bools: [String: Bool]
    var integers: [String: Int]
    var strings: [String: String]
    var stringArrays: [String: [String]]
    var excludedApplications: [BackupExcludedApplication]

    init(
        bools: [String: Bool] = [:],
        integers: [String: Int] = [:],
        strings: [String: String] = [:],
        stringArrays: [String: [String]] = [:],
        excludedApplications: [BackupExcludedApplication] = []
    ) {
        self.bools = bools
        self.integers = integers
        self.strings = strings
        self.stringArrays = stringArrays
        self.excludedApplications = excludedApplications
    }
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

struct BackupPreview: Equatable {
    var format: String
    var version: Int
    var appVersion: String
    var exportedAt: Date
    var sections: Set<BackupSection>
    var settingsValueCount: Int
    var excludedApplicationCount: Int
    var snippetFolderCount: Int
    var snippetCount: Int
    var historyItemCount: Int
    var historyAssetCount: Int
    var historyThumbnailCount: Int

    init(document: BackupDocument) {
        var sections = Set<BackupSection>()
        if document.settings != nil { sections.insert(.settings) }
        if document.snippets != nil { sections.insert(.snippets) }
        if document.history != nil { sections.insert(.history) }

        let settings = document.settings
        let snippets = document.snippets ?? []
        let history = document.history ?? []

        self.format = document.format
        self.version = document.version
        self.appVersion = document.appVersion
        self.exportedAt = document.exportedAt
        self.sections = sections
        settingsValueCount = (settings?.bools.count ?? 0)
            + (settings?.integers.count ?? 0)
            + (settings?.strings.count ?? 0)
            + (settings?.stringArrays.count ?? 0)
        excludedApplicationCount = settings?.excludedApplications.count ?? 0
        snippetFolderCount = snippets.count
        snippetCount = snippets.reduce(0) { $0 + $1.snippets.count }
        historyItemCount = history.count
        historyAssetCount = history.reduce(0) { $0 + $1.assets.count }
        historyThumbnailCount = history.filter { $0.thumbnail != nil }.count
    }
}

enum BackupError: Error, Equatable {
    case invalidFormat(String)
    case unsupportedVersion(Int)
    case restoreNotImplemented
}

extension SnippetTransferFolder: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case index
        case isEnabled
        case snippets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        snippets = try container.decode([SnippetTransferSnippet].self, forKey: .snippets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(index, forKey: .index)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(snippets, forKey: .snippets)
    }
}

extension SnippetTransferSnippet: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case index
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(index, forKey: .index)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}
