//
//  PasteboardHistoryRepository.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import AppKit
import Foundation
import SQLite3

protocol PasteboardHistoryRepositoryProtocol {
    func observeHistories() -> NotificationCenter.Notifications
    func hasHistories() -> Bool
    func fetchHistoryDetails(
        ascending: Bool,
        includesThumbnailAsset: Bool,
        limit: Int
    ) -> [PasteboardHistoryDetail]
    func fetchHistory(id: PasteboardHistory.ID) -> PasteboardHistory?
    func fetchContent(id: PasteboardHistory.ID) -> PasteboardContent?

    func save(id: PasteboardHistory.ID, content: PasteboardContent, updateAt: Int)
    func deleteHistory(id: PasteboardHistory.ID)
    func deleteAll()
    func deleteOverflowingHistories(maxHistorySize: Int)
}

final class PasteboardHistoryRepository: PasteboardHistoryRepositoryProtocol {
    static let historyDidChangeNotification = Notification.Name("com.knoseman.reclipt.PasteboardHistoryRepository.historyDidChange")

    private let store = SQLiteStore.shared

    // MARK: - Observation

    func observeHistories() -> NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: Self.historyDidChangeNotification)
    }

    // MARK: - Queries

    func hasHistories() -> Bool {
        do {
            return try store.read { database in
                var statement: OpaquePointer?
                let sql = "SELECT 1 FROM pasteboardHistories LIMIT 1"
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                    return false
                }
                defer { sqlite3_finalize(statement) }
                return sqlite3_step(statement) == SQLITE_ROW
            }
        } catch {
            return false
        }
    }

    func fetchHistoryDetails(
        ascending: Bool,
        includesThumbnailAsset: Bool,
        limit: Int
    ) -> [PasteboardHistoryDetail] {
        do {
            return try store.read { database in
                let order = ascending ? "ASC" : "DESC"
                let sql = """
                    SELECT h.id, h.title, h.pasteboardTypes, h.deviceID, h.updateAt
                    FROM pasteboardHistories h
                    ORDER BY h.updateAt \(order)
                    LIMIT ?
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                    return []
                }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindInt(statement!, index: 1, value: limit)

                var histories = [PasteboardHistory]()
                while sqlite3_step(statement) == SQLITE_ROW {
                    histories.append(parseHistory(statement!))
                }

                guard includesThumbnailAsset else {
                    return histories.map { PasteboardHistoryDetail(history: $0, thumbnailAsset: nil) }
                }

                return histories.map { history in
                    let thumbnail = fetchThumbnailAsset(database: database, historyID: history.id)
                    return PasteboardHistoryDetail(history: history, thumbnailAsset: thumbnail)
                }
            }
        } catch {
            return []
        }
    }

    func fetchHistory(id: PasteboardHistory.ID) -> PasteboardHistory? {
        do {
            return try store.read { database in
                let sql = "SELECT id, title, pasteboardTypes, deviceID, updateAt FROM pasteboardHistories WHERE id = ? LIMIT 1"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                    return nil
                }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: id)
                guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
                return parseHistory(statement!)
            }
        } catch {
            return nil
        }
    }

    func fetchContent(id: PasteboardHistory.ID) -> PasteboardContent? {
        do {
            return try store.read { database in
                let sql = "SELECT pasteboardType, data FROM pasteboardHistoryAssets WHERE pasteboardHistoryID = ? ORDER BY index ASC"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                    return nil
                }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: id)

                var assets = [PasteboardContent.Asset]()
                while sqlite3_step(statement) == SQLITE_ROW {
                    let type = NSPasteboard.PasteboardType(SQLiteStore.columnText(statement!, index: 0))
                    let data = SQLiteStore.columnData(statement!, index: 1)
                    assets.append(PasteboardContent.Asset(type: type, data: data))
                }
                return PasteboardContent(assets: assets)
            }
        } catch {
            return nil
        }
    }

    // MARK: - Mutations

    func save(id: PasteboardHistory.ID, content: PasteboardContent, updateAt: Int) {
        do {
            try store.write { database in
                let existsSQL = "SELECT 1 FROM pasteboardHistories WHERE id = ? LIMIT 1"
                var existsStmt: OpaquePointer?
                guard sqlite3_prepare_v2(database, existsSQL, -1, &existsStmt, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(existsStmt) }
                SQLiteStore.bindText(existsStmt!, index: 1, value: id)
                let exists = sqlite3_step(existsStmt) == SQLITE_ROW

                let historySQL = """
                    INSERT OR REPLACE INTO pasteboardHistories (id, title, pasteboardTypes, deviceID, updateAt)
                    VALUES (?, ?, ?, ?, ?)
                """
                var historyStmt: OpaquePointer?
                guard sqlite3_prepare_v2(database, historySQL, -1, &historyStmt, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(historyStmt) }
                SQLiteStore.bindText(historyStmt!, index: 1, value: id)
                SQLiteStore.bindText(historyStmt!, index: 2, value: content.stringValue.prefix(10000).description)
                SQLiteStore.bindText(historyStmt!, index: 3, value: NSPasteboard.PasteboardType.toJSON(content.types))
                SQLiteStore.bindText(historyStmt!, index: 4, value: ReCliptUtilities.deviceID ?? "")
                SQLiteStore.bindInt(historyStmt!, index: 5, value: updateAt)
                sqlite3_step(historyStmt)

                if !exists {
                    let assetSQL = """
                        INSERT INTO pasteboardHistoryAssets (id, pasteboardHistoryID, index, pasteboardType, data)
                        VALUES (?, ?, ?, ?, ?)
                    """
                    for (index, asset) in content.assets.enumerated() {
                        var assetStmt: OpaquePointer?
                        guard sqlite3_prepare_v2(database, assetSQL, -1, &assetStmt, nil) == SQLITE_OK else { continue }
                        defer { sqlite3_finalize(assetStmt) }
                        SQLiteStore.bindText(assetStmt!, index: 1, value: UUID().uuidString)
                        SQLiteStore.bindText(assetStmt!, index: 2, value: id)
                        SQLiteStore.bindInt(assetStmt!, index: 3, value: index)
                        SQLiteStore.bindText(assetStmt!, index: 4, value: asset.type.rawValue)
                        SQLiteStore.bindData(assetStmt!, index: 5, value: asset.data)
                        sqlite3_step(assetStmt)
                    }

                    if let thumbnail = thumbnailAsset(from: content, id: id) {
                        let thumbSQL = """
                            INSERT INTO pasteboardHistoryThumbnailAssets (pasteboardHistoryID, kind, data)
                            VALUES (?, ?, ?)
                        """
                        var thumbStmt: OpaquePointer?
                        guard sqlite3_prepare_v2(database, thumbSQL, -1, &thumbStmt, nil) == SQLITE_OK else { return }
                        defer { sqlite3_finalize(thumbStmt) }
                        SQLiteStore.bindText(thumbStmt!, index: 1, value: thumbnail.pasteboardHistoryID)
                        SQLiteStore.bindText(thumbStmt!, index: 2, value: thumbnail.kind.rawValue)
                        SQLiteStore.bindData(thumbStmt!, index: 3, value: thumbnail.data)
                        sqlite3_step(thumbStmt)
                    }
                }
            }
            NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: nil)
        } catch {
            // Silently fail for now
        }
    }

    func deleteHistory(id: PasteboardHistory.ID) {
        do {
            try store.write { database in
                let sql = "DELETE FROM pasteboardHistories WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: id)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func deleteAll() {
        do {
            try store.write { database in
                let sql = "DELETE FROM pasteboardHistories"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func deleteOverflowingHistories(maxHistorySize: Int) {
        guard maxHistorySize > 0 else {
            deleteAll()
            return
        }
        do {
            try store.write { database in
                let sql = """
                    DELETE FROM pasteboardHistories
                    WHERE id IN (
                        SELECT id FROM pasteboardHistories
                        ORDER BY updateAt DESC
                        LIMIT -1 OFFSET ?
                    )
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindInt(statement!, index: 1, value: maxHistorySize)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    // MARK: - Private Helpers

    private func parseHistory(_ statement: OpaquePointer) -> PasteboardHistory {
        let id = SQLiteStore.columnText(statement, index: 0)
        let title = SQLiteStore.columnText(statement, index: 1)
        let typesJSON = SQLiteStore.columnText(statement, index: 2)
        let deviceID = SQLiteStore.columnText(statement, index: 3)
        let updateAt = SQLiteStore.columnInt(statement, index: 4)
        return PasteboardHistory(
            id: id,
            title: title,
            pasteboardTypes: NSPasteboard.PasteboardType.fromJSON(typesJSON),
            updateAt: updateAt,
            deviceID: deviceID.isEmpty ? nil : deviceID
        )
    }

    private func fetchThumbnailAsset(database: OpaquePointer, historyID: PasteboardHistory.ID) -> PasteboardHistoryThumbnailAsset? {
        let sql = "SELECT kind, data FROM pasteboardHistoryThumbnailAssets WHERE pasteboardHistoryID = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        SQLiteStore.bindText(statement!, index: 1, value: historyID)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let kindRaw = SQLiteStore.columnText(statement!, index: 0)
        guard let kind = PasteboardHistoryThumbnailAsset.Kind(rawValue: kindRaw) else { return nil }
        let data = SQLiteStore.columnData(statement!, index: 1)
        return PasteboardHistoryThumbnailAsset(pasteboardHistoryID: historyID, kind: kind, data: data)
    }

    private func thumbnailAsset(from content: PasteboardContent, id: PasteboardHistory.ID) -> PasteboardHistoryThumbnailAsset? {
        var asset: PasteboardHistoryThumbnailAsset?
        if let thumbnailImage = content.thumbnailImage, let thumbnailData = thumbnailImage.tiffRepresentation {
            asset = PasteboardHistoryThumbnailAsset(
                pasteboardHistoryID: id,
                kind: .image,
                data: thumbnailData
            )
        }
        if let colorCodeImage = content.colorCodeImage, let colorCodeData = colorCodeImage.tiffRepresentation {
            asset = PasteboardHistoryThumbnailAsset(
                pasteboardHistoryID: id,
                kind: .colorCode,
                data: colorCodeData
            )
        }
        return asset
    }
}
