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
            try SQLiteStore.shared.read { database in
                #expect(sqlite3_db_filename(database, "main") != nil)
            }
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

    @Test(.timeLimit(.minutes(1)))
    func openAsyncCompletesAndMigratesSchema() throws {
        let store = SQLiteStore.shared
        store.close()

        try waitForAsyncOpen(store).get()
        defer { try? TestSQLiteStore.clear(store) }

        try store.read { database in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
                Issue.record("Failed to prepare user_version statement")
                return
            }
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                Issue.record("user_version did not return a row")
                return
            }

            #expect(sqlite3_column_int(statement, 0) == 1)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrentOpenAsyncCallsAreIdempotent() throws {
        let store = SQLiteStore.shared
        store.close()

        let lock = NSLock()
        var results = [Result<Void, Error>]()
        let group = DispatchGroup()

        for _ in 0..<8 {
            group.enter()
            store.openAsync { result in
                lock.withLock {
                    results.append(result)
                }
                group.leave()
            }
        }

        #expect(group.wait(timeout: .now() + 5) == .success)
        #expect(results.count == 8)
        #expect(results.allSatisfy { result in
            if case .success = result { return true }
            return false
        })
        try TestSQLiteStore.clear(store)
    }

    @Test(.timeLimit(.minutes(1)))
    func repositoriesAreUsableAfterAsyncOpen() throws {
        let store = SQLiteStore.shared
        store.close()

        try waitForAsyncOpen(store).get()
        try TestSQLiteStore.clear(store)
        defer { try? TestSQLiteStore.clear(store) }

        let historyRepository = PasteboardHistoryRepository()
        let content = try #require(
            PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Async Ready".utf8))])
        )
        historyRepository.save(id: "async-ready", content: content, updateAt: 1000)

        let snippetRepository = SnippetRepository()
        let folder = try #require(snippetRepository.insertFolder())
        snippetRepository.updateFolderTitle(folder.id, title: "Async Folder")

        #expect(historyRepository.fetchHistory(id: "async-ready")?.title == "Async Ready")
        #expect(snippetRepository.fetchFolderDetail(id: folder.id)?.folder.title == "Async Folder")
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

    private func waitForAsyncOpen(_ store: SQLiteStore) -> Result<Void, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<Void, Error>?

        store.openAsync { openResult in
            lock.withLock {
                result = openResult
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 5) == .success else {
            return .failure(SQLiteStoreError.unknown("Timed out waiting for async open"))
        }

        return lock.withLock {
            result ?? .failure(SQLiteStoreError.unknown("Async open completed without a result"))
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

    static func clear(_ store: SQLiteStore) throws {
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
