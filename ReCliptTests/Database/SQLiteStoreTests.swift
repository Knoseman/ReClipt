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
