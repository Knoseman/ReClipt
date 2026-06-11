//
//  SnippetRepository.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Foundation
import SQLite3

protocol SnippetRepositoryProtocol {
    func observeFolderDetails() -> NotificationCenter.Notifications
    func fetchFolderDetails() -> [SnippetFolderDetail]
    func fetchFolderDetail(id: SnippetFolder.ID) -> SnippetFolderDetail?

    func insertFolder() -> SnippetFolder?
    func insertFolders(_ folders: [(title: String, snippets: [(title: String, content: String)])]) -> [SnippetFolderDetail]?
    func updateFolderTitle(_ id: SnippetFolder.ID, title: String)
    func updateFolderIsEnabled(_ id: SnippetFolder.ID, isEnabled: Bool)
    func updateFolderIndexes(_ folderIDs: [SnippetFolder.ID])
    func deleteFolder(_ id: SnippetFolder.ID)

    func fetchSnippet(id: Snippet.ID) -> Snippet?
    func insertSnippet(to id: SnippetFolder.ID) -> Snippet?
    func updateSnippetTitle(_ id: Snippet.ID, title: String)
    func updateSnippetContent(_ id: Snippet.ID, content: String)
    func updateSnippetIsEnabled(_ id: Snippet.ID, isEnabled: Bool)
    func updateSnippetIndexes(_ snippetIDs: [Snippet.ID])
    func moveSnippet(_ id: Snippet.ID, to folderID: SnippetFolder.ID, snippetIDs: [Snippet.ID])
    func deleteSnippet(_ id: Snippet.ID)
}

final class SnippetRepository: SnippetRepositoryProtocol {
    static let snippetsDidChangeNotification = Notification.Name("com.knoseman.reclipt.SnippetRepository.snippetsDidChange")

    private let store = SQLiteStore.shared

    // MARK: - Observation

    func observeFolderDetails() -> NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: Self.snippetsDidChangeNotification)
    }

    // MARK: - Queries

    func fetchFolderDetails() -> [SnippetFolderDetail] {
        do {
            return try store.read { database in
                let folders = fetchAllFolders(database: database)
                let snippets = fetchAllSnippets(database: database)
                return Self.folderDetails(folders: folders, snippets: snippets)
            }
        } catch {
            return []
        }
    }

    func fetchFolderDetail(id: SnippetFolder.ID) -> SnippetFolderDetail? {
        do {
            return try store.read { database in
                guard let folder = fetchFolder(database: database, id: id) else { return nil }
                let snippets = fetchSnippetsForFolder(database: database, folderID: id)
                return SnippetFolderDetail(folder: folder, snippets: snippets)
            }
        } catch {
            return nil
        }
    }

    func fetchSnippet(id: Snippet.ID) -> Snippet? {
        do {
            return try store.read { database in
                let sql = "SELECT id, folderID, title, content, \"index\", isEnabled FROM snippets WHERE id = ? LIMIT 1"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: id.uuidString)
                guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
                return parseSnippet(statement!)
            }
        } catch {
            return nil
        }
    }

    // MARK: - Folder Mutations

    func insertFolder() -> SnippetFolder? {
        do {
            var result: SnippetFolder?
            try store.write { database in
                let lastIndex = fetchMaxFolderIndex(database: database)
                let folder = SnippetFolder(
                    id: UUID(),
                    title: "untitled folder",
                    index: lastIndex + 1,
                    isEnabled: true
                )
                let sql = """
                    INSERT INTO snippetFolders (id, title, "index", isEnabled)
                    VALUES (?, ?, ?, ?)
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: folder.id.uuidString)
                SQLiteStore.bindText(statement!, index: 2, value: folder.title)
                SQLiteStore.bindInt(statement!, index: 3, value: folder.index)
                SQLiteStore.bindInt(statement!, index: 4, value: folder.isEnabled ? 1 : 0)
                sqlite3_step(statement)
                result = folder
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
            return result
        } catch {
            return nil
        }
    }

    func insertFolders(_ folders: [(title: String, snippets: [(title: String, content: String)])]) -> [SnippetFolderDetail]? {
        do {
            var result = [SnippetFolderDetail]()
            try store.write { database in
                let lastIndex = fetchMaxFolderIndex(database: database)
                for (index, folderData) in folders.enumerated() {
                    let folder = SnippetFolder(
                        id: UUID(),
                        title: folderData.title,
                        index: lastIndex + index + 1,
                        isEnabled: true
                    )
                    let folderSQL = """
                        INSERT INTO snippetFolders (id, title, "index", isEnabled)
                        VALUES (?, ?, ?, ?)
                    """
                    var folderStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(database, folderSQL, -1, &folderStmt, nil) == SQLITE_OK else { continue }
                    defer { sqlite3_finalize(folderStmt) }
                    SQLiteStore.bindText(folderStmt!, index: 1, value: folder.id.uuidString)
                    SQLiteStore.bindText(folderStmt!, index: 2, value: folder.title)
                    SQLiteStore.bindInt(folderStmt!, index: 3, value: folder.index)
                    SQLiteStore.bindInt(folderStmt!, index: 4, value: folder.isEnabled ? 1 : 0)
                    sqlite3_step(folderStmt)

                    var snippets = [Snippet]()
                    for (snippetIndex, snippetData) in folderData.snippets.enumerated() {
                        let snippet = Snippet(
                            id: UUID(),
                            folderID: folder.id,
                            title: snippetData.title,
                            content: snippetData.content,
                            index: snippetIndex,
                            isEnabled: true
                        )
                        let snippetSQL = """
                            INSERT INTO snippets (id, folderID, title, content, "index", isEnabled)
                            VALUES (?, ?, ?, ?, ?, ?)
                        """
                        var snippetStmt: OpaquePointer?
                        guard sqlite3_prepare_v2(database, snippetSQL, -1, &snippetStmt, nil) == SQLITE_OK else { continue }
                        defer { sqlite3_finalize(snippetStmt) }
                        SQLiteStore.bindText(snippetStmt!, index: 1, value: snippet.id.uuidString)
                        SQLiteStore.bindText(snippetStmt!, index: 2, value: snippet.folderID.uuidString)
                        SQLiteStore.bindText(snippetStmt!, index: 3, value: snippet.title)
                        SQLiteStore.bindText(snippetStmt!, index: 4, value: snippet.content)
                        SQLiteStore.bindInt(snippetStmt!, index: 5, value: snippet.index)
                        SQLiteStore.bindInt(snippetStmt!, index: 6, value: snippet.isEnabled ? 1 : 0)
                        sqlite3_step(snippetStmt)
                        snippets.append(snippet)
                    }
                    result.append(SnippetFolderDetail(folder: folder, snippets: snippets))
                }
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
            return result.isEmpty ? nil : result
        } catch {
            return nil
        }
    }

    func updateFolderTitle(_ id: SnippetFolder.ID, title: String) {
        do {
            try store.write { database in
                let sql = "UPDATE snippetFolders SET title = ? WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: title)
                SQLiteStore.bindText(statement!, index: 2, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func updateFolderIsEnabled(_ id: SnippetFolder.ID, isEnabled: Bool) {
        do {
            try store.write { database in
                let sql = "UPDATE snippetFolders SET isEnabled = ? WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindInt(statement!, index: 1, value: isEnabled ? 1 : 0)
                SQLiteStore.bindText(statement!, index: 2, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func updateFolderIndexes(_ folderIDs: [SnippetFolder.ID]) {
        do {
            try store.write { database in
                let sql = "UPDATE snippetFolders SET \"index\" = ? WHERE id = ?"
                for (index, folderID) in folderIDs.enumerated() {
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { continue }
                    defer { sqlite3_finalize(statement) }
                    SQLiteStore.bindInt(statement!, index: 1, value: index)
                    SQLiteStore.bindText(statement!, index: 2, value: folderID.uuidString)
                    sqlite3_step(statement)
                }
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func deleteFolder(_ id: SnippetFolder.ID) {
        do {
            try store.write { database in
                let sql = "DELETE FROM snippetFolders WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    // MARK: - Snippet Mutations

    func insertSnippet(to id: SnippetFolder.ID) -> Snippet? {
        do {
            var result: Snippet?
            try store.write { database in
                let lastIndex = fetchMaxSnippetIndex(database: database, folderID: id)
                let snippet = Snippet(
                    id: UUID(),
                    folderID: id,
                    title: "untitled snippet",
                    content: "",
                    index: lastIndex + 1,
                    isEnabled: true
                )
                let sql = """
                    INSERT INTO snippets (id, folderID, title, content, "index", isEnabled)
                    VALUES (?, ?, ?, ?, ?, ?)
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: snippet.id.uuidString)
                SQLiteStore.bindText(statement!, index: 2, value: snippet.folderID.uuidString)
                SQLiteStore.bindText(statement!, index: 3, value: snippet.title)
                SQLiteStore.bindText(statement!, index: 4, value: snippet.content)
                SQLiteStore.bindInt(statement!, index: 5, value: snippet.index)
                SQLiteStore.bindInt(statement!, index: 6, value: snippet.isEnabled ? 1 : 0)
                sqlite3_step(statement)
                result = snippet
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
            return result
        } catch {
            return nil
        }
    }

    func updateSnippetTitle(_ id: Snippet.ID, title: String) {
        do {
            try store.write { database in
                let sql = "UPDATE snippets SET title = ? WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: title)
                SQLiteStore.bindText(statement!, index: 2, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func updateSnippetContent(_ id: Snippet.ID, content: String) {
        do {
            try store.write { database in
                let sql = "UPDATE snippets SET content = ? WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: content)
                SQLiteStore.bindText(statement!, index: 2, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func updateSnippetIsEnabled(_ id: Snippet.ID, isEnabled: Bool) {
        do {
            try store.write { database in
                let sql = "UPDATE snippets SET isEnabled = ? WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindInt(statement!, index: 1, value: isEnabled ? 1 : 0)
                SQLiteStore.bindText(statement!, index: 2, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func updateSnippetIndexes(_ snippetIDs: [Snippet.ID]) {
        do {
            try store.write { database in
                let sql = "UPDATE snippets SET \"index\" = ? WHERE id = ?"
                for (index, snippetID) in snippetIDs.enumerated() {
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { continue }
                    defer { sqlite3_finalize(statement) }
                    SQLiteStore.bindInt(statement!, index: 1, value: index)
                    SQLiteStore.bindText(statement!, index: 2, value: snippetID.uuidString)
                    sqlite3_step(statement)
                }
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func moveSnippet(_ id: Snippet.ID, to folderID: SnippetFolder.ID, snippetIDs: [Snippet.ID]) {
        do {
            try store.write { database in
                let sql1 = "UPDATE snippets SET folderID = ? WHERE id = ?"
                var stmt1: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql1, -1, &stmt1, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(stmt1) }
                SQLiteStore.bindText(stmt1!, index: 1, value: folderID.uuidString)
                SQLiteStore.bindText(stmt1!, index: 2, value: id.uuidString)
                sqlite3_step(stmt1)

                let sql2 = "UPDATE snippets SET \"index\" = ? WHERE id = ?"
                for (index, snippetID) in snippetIDs.enumerated() {
                    var stmt2: OpaquePointer?
                    guard sqlite3_prepare_v2(database, sql2, -1, &stmt2, nil) == SQLITE_OK else { continue }
                    defer { sqlite3_finalize(stmt2) }
                    SQLiteStore.bindInt(stmt2!, index: 1, value: index)
                    SQLiteStore.bindText(stmt2!, index: 2, value: snippetID.uuidString)
                    sqlite3_step(stmt2)
                }
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    func deleteSnippet(_ id: Snippet.ID) {
        do {
            try store.write { database in
                let sql = "DELETE FROM snippets WHERE id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                SQLiteStore.bindText(statement!, index: 1, value: id.uuidString)
                sqlite3_step(statement)
            }
            NotificationCenter.default.post(name: Self.snippetsDidChangeNotification, object: nil)
        } catch {
            // Silently fail
        }
    }

    // MARK: - Private Helpers

    private func fetchAllFolders(database: OpaquePointer) -> [SnippetFolder] {
        let sql = "SELECT id, title, \"index\", isEnabled FROM snippetFolders ORDER BY \"index\""
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var folders = [SnippetFolder]()
        while sqlite3_step(statement) == SQLITE_ROW {
            folders.append(parseFolder(statement!))
        }
        return folders
    }

    private func fetchAllSnippets(database: OpaquePointer) -> [Snippet] {
        let sql = "SELECT id, folderID, title, content, \"index\", isEnabled FROM snippets ORDER BY \"index\""
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var snippets = [Snippet]()
        while sqlite3_step(statement) == SQLITE_ROW {
            snippets.append(parseSnippet(statement!))
        }
        return snippets
    }

    private func fetchFolder(database: OpaquePointer, id: SnippetFolder.ID) -> SnippetFolder? {
        let sql = "SELECT id, title, \"index\", isEnabled FROM snippetFolders WHERE id = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        SQLiteStore.bindText(statement!, index: 1, value: id.uuidString)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return parseFolder(statement!)
    }

    private func fetchSnippetsForFolder(database: OpaquePointer, folderID: SnippetFolder.ID) -> [Snippet] {
        let sql = "SELECT id, folderID, title, content, \"index\", isEnabled FROM snippets WHERE folderID = ? ORDER BY \"index\""
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        SQLiteStore.bindText(statement!, index: 1, value: folderID.uuidString)
        var snippets = [Snippet]()
        while sqlite3_step(statement) == SQLITE_ROW {
            snippets.append(parseSnippet(statement!))
        }
        return snippets
    }

    private func fetchMaxFolderIndex(database: OpaquePointer) -> Int {
        let sql = "SELECT MAX(\"index\") FROM snippetFolders"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return -1 }
        return SQLiteStore.columnInt(statement!, index: 0)
    }

    private func fetchMaxSnippetIndex(database: OpaquePointer, folderID: SnippetFolder.ID) -> Int {
        let sql = "SELECT MAX(\"index\") FROM snippets WHERE folderID = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(statement) }
        SQLiteStore.bindText(statement!, index: 1, value: folderID.uuidString)
        guard sqlite3_step(statement) == SQLITE_ROW else { return -1 }
        return SQLiteStore.columnInt(statement!, index: 0)
    }

    private func parseFolder(_ statement: OpaquePointer) -> SnippetFolder {
        let id = UUID(uuidString: SQLiteStore.columnText(statement, index: 0)) ?? UUID()
        let title = SQLiteStore.columnText(statement, index: 1)
        let index = SQLiteStore.columnInt(statement, index: 2)
        let isEnabled = SQLiteStore.columnBool(statement, index: 3)
        return SnippetFolder(id: id, title: title, index: index, isEnabled: isEnabled)
    }

    private func parseSnippet(_ statement: OpaquePointer) -> Snippet {
        let id = UUID(uuidString: SQLiteStore.columnText(statement, index: 0)) ?? UUID()
        let folderID = UUID(uuidString: SQLiteStore.columnText(statement, index: 1)) ?? UUID()
        let title = SQLiteStore.columnText(statement, index: 2)
        let content = SQLiteStore.columnText(statement, index: 3)
        let index = SQLiteStore.columnInt(statement, index: 4)
        let isEnabled = SQLiteStore.columnBool(statement, index: 5)
        return Snippet(id: id, folderID: folderID, title: title, content: content, index: index, isEnabled: isEnabled)
    }

    static func folderDetails(folders: [SnippetFolder], snippets: [Snippet]) -> [SnippetFolderDetail] {
        let snippetsByFolderID = Dictionary(grouping: snippets, by: \.folderID)
        return folders.map { folder in
            SnippetFolderDetail(folder: folder, snippets: snippetsByFolderID[folder.id] ?? [])
        }
    }
}
