//
//  SQLiteStoreTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/09.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Foundation
import SQLite3
import Testing
@testable import ReClipt

@MainActor
@Suite
struct SQLiteStoreTests {
    @Test
    func openAndClose() throws {
        let store = SQLiteStore.shared
        try store.open()
        #expect(store != nil)
        store.close()
    }

    @Test
    func schemaCreation() throws {
        let store = SQLiteStore.shared
        try store.open()
        defer { store.close() }

        try store.read { database in
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
