//
//  SQLiteStoreTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Foundation
import SQLite3
import Testing
@testable import ReClipt

@MainActor
@Suite(.serialized)
struct SQLiteStoreTests {
    @Test
    func openAndClose() throws {
        try TestSQLiteStore.withCleanStore {
            let store = SQLiteStore.shared
            try store.open()
            #expect(store != nil)
        }
    }

    @Test
    func schemaCreation() throws {
        try TestSQLiteStore.withCleanStore {
            try SQLiteStore.shared.read { database in
                var statement: OpaquePointer?
                let sql = """
                    SELECT name FROM sqlite_master
                    WHERE type = 'table' AND name IN (
                        'pasteboardHistories',
                        'pasteboardHistoryAssets',
                        'pasteboardHistoryThumbnailAssets',
                        'snippetFolders',
                        'snippets'
                    )
                    ORDER BY name
                """
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                    Issue.record("Failed to prepare statement")
                    return
                }
                defer { sqlite3_finalize(statement) }

                var tables = [String]()
                while sqlite3_step(statement) == SQLITE_ROW {
                    tables.append(String(cString: sqlite3_column_text(statement, 0)))
                }

                #expect(tables == [
                    "pasteboardHistories",
                    "pasteboardHistoryAssets",
                    "pasteboardHistoryThumbnailAssets",
                    "snippetFolders",
                    "snippets"
                ])
            }
        }
    }

    @Test
    func openEnablesWriteAheadLogging() throws {
        try TestSQLiteStore.withCleanStore {
            try SQLiteStore.shared.read { database in
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, "PRAGMA journal_mode", -1, &statement, nil) == SQLITE_OK else {
                    Issue.record("Failed to prepare journal_mode statement")
                    return
                }
                defer { sqlite3_finalize(statement) }

                guard sqlite3_step(statement) == SQLITE_ROW else {
                    Issue.record("journal_mode did not return a row")
                    return
                }

                #expect(String(cString: sqlite3_column_text(statement, 0)).lowercased() == "wal")
            }
        }
    }

    @Test
    func openEnablesForeignKeyConstraints() throws {
        try TestSQLiteStore.withCleanStore {
            try SQLiteStore.shared.read { database in
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, "PRAGMA foreign_keys", -1, &statement, nil) == SQLITE_OK else {
                    Issue.record("Failed to prepare foreign_keys statement")
                    return
                }
                defer { sqlite3_finalize(statement) }

                guard sqlite3_step(statement) == SQLITE_ROW else {
                    Issue.record("foreign_keys did not return a row")
                    return
                }

                #expect(sqlite3_column_int(statement, 0) == 1)
            }
        }
    }

    @Test
    func writeRollsBackWhenClosureThrows() throws {
        try TestSQLiteStore.withCleanStore {
            let store = SQLiteStore.shared

            do {
                try store.write { database in
                    let sql = """
                        INSERT INTO pasteboardHistories (id, title, pasteboardTypes, deviceID, updateAt)
                        VALUES ('rollback-test', 'Rollback', '[]', '', 1)
                    """
                    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                        throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
                    }
                    throw SQLiteStoreError.unknown("Force rollback")
                }
            } catch {
                // Expected.
            }

            try store.read { database in
                var statement: OpaquePointer?
                let sql = "SELECT COUNT(*) FROM pasteboardHistories WHERE id = 'rollback-test'"
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                    Issue.record("Failed to prepare rollback count")
                    return
                }
                defer { sqlite3_finalize(statement) }
                guard sqlite3_step(statement) == SQLITE_ROW else {
                    Issue.record("Rollback count did not return a row")
                    return
                }
                #expect(sqlite3_column_int(statement, 0) == 0)
            }
        }
    }
}

enum TestSQLiteStore {
    private static let lock = NSRecursiveLock()

    static func withCleanStore(_ closure: () throws -> Void) throws {
        lock.lock()
        defer { lock.unlock() }

        let store = SQLiteStore.shared
        try store.open()
        try clear(store)
        try closure()
        try clear(store)
    }

    private static func clear(_ store: SQLiteStore) throws {
        try store.write { database in
            for sql in [
                "DELETE FROM pasteboardHistoryThumbnailAssets",
                "DELETE FROM pasteboardHistoryAssets",
                "DELETE FROM pasteboardHistories",
                "DELETE FROM snippets",
                "DELETE FROM snippetFolders"
            ] {
                guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                    throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
                }
            }
        }
    }
}
