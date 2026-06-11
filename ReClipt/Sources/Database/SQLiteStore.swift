//
//  SQLiteStore.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteStoreError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case constraintViolation(String)
    case unknown(String)
}

final class SQLiteStore {
    static let shared = SQLiteStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.knoseman.reclipt.SQLiteStore", qos: .utility)
    private let lock = NSRecursiveLock(name: "com.knoseman.reclipt.SQLiteStore")

    private init() {}

    // MARK: - Lifecycle

    func open() throws {
        try queue.sync {
            lock.lock(); defer { lock.unlock() }
            guard db == nil else { return }

            let path = try databasePath()
            let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
            var newDb: OpaquePointer?
            let result = sqlite3_open_v2(path, &newDb, flags, nil)
            guard result == SQLITE_OK, let database = newDb else {
                let message = String(cString: sqlite3_errmsg(newDb))
                sqlite3_close(newDb)
                throw SQLiteStoreError.openFailed(message)
            }
            db = database
            try migrate(database)
        }
    }

    func close() {
        queue.sync {
            lock.lock(); defer { lock.unlock() }
            if let database = db {
                sqlite3_close(database)
                db = nil
            }
        }
    }

    // MARK: - Transactions

    func read<T>(_ closure: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            lock.lock(); defer { lock.unlock() }
            guard let database = db else {
                throw SQLiteStoreError.unknown("Database not open")
            }
            return try closure(database)
        }
    }

    func write(_ closure: (OpaquePointer) throws -> Void) throws {
        try queue.sync {
            lock.lock(); defer { lock.unlock() }
            guard let database = db else {
                throw SQLiteStoreError.unknown("Database not open")
            }
            try execute(database, sql: "BEGIN IMMEDIATE TRANSACTION")
            do {
                try closure(database)
                try execute(database, sql: "COMMIT")
            } catch {
                try? execute(database, sql: "ROLLBACK")
                throw error
            }
        }
    }

    // MARK: - Schema

    private func migrate(_ database: OpaquePointer) throws {
        let version = try userVersion(database)
        if version < 1 {
            try createSchemaV1(database)
            try setUserVersion(database, version: 1)
        }
    }

    private func createSchemaV1(_ database: OpaquePointer) throws {
        try execute(database, sql: """
            CREATE TABLE IF NOT EXISTS "pasteboardHistories" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "title" TEXT NOT NULL DEFAULT '',
                "pasteboardTypes" TEXT NOT NULL DEFAULT '[]',
                "deviceID" TEXT,
                "updateAt" INTEGER NOT NULL DEFAULT 0
            ) STRICT
        """)
        try execute(database, sql: """
            CREATE INDEX IF NOT EXISTS "index_pasteboardHistories_on_updateAt"
            ON "pasteboardHistories" ("updateAt")
        """)
        try execute(database, sql: """
            CREATE TABLE IF NOT EXISTS "pasteboardHistoryAssets" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "pasteboardHistoryID" TEXT NOT NULL,
                "index" INTEGER NOT NULL DEFAULT 0,
                "pasteboardType" TEXT NOT NULL DEFAULT '',
                "data" BLOB NOT NULL,
                FOREIGN KEY ("pasteboardHistoryID")
                    REFERENCES "pasteboardHistories" ("id")
                    ON DELETE CASCADE
            ) STRICT
        """)
        try execute(database, sql: """
            CREATE INDEX IF NOT EXISTS "index_pasteboardHistoryAssets_on_pasteboardHistoryID_index"
            ON "pasteboardHistoryAssets" ("pasteboardHistoryID", "index")
        """)
        try execute(database, sql: """
            CREATE TABLE IF NOT EXISTS "pasteboardHistoryThumbnailAssets" (
                "pasteboardHistoryID" TEXT PRIMARY KEY NOT NULL,
                "kind" TEXT NOT NULL DEFAULT '',
                "data" BLOB NOT NULL,
                FOREIGN KEY ("pasteboardHistoryID")
                    REFERENCES "pasteboardHistories" ("id")
                    ON DELETE CASCADE
            ) STRICT
        """)
        try execute(database, sql: """
            CREATE TABLE IF NOT EXISTS "snippetFolders" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "title" TEXT NOT NULL DEFAULT '',
                "index" INTEGER NOT NULL DEFAULT 0,
                "isEnabled" INTEGER NOT NULL DEFAULT 1
            ) STRICT
        """)
        try execute(database, sql: """
            CREATE TABLE IF NOT EXISTS "snippets" (
                "id" TEXT PRIMARY KEY NOT NULL,
                "folderID" TEXT NOT NULL,
                "title" TEXT NOT NULL DEFAULT '',
                "content" TEXT NOT NULL DEFAULT '',
                "index" INTEGER NOT NULL DEFAULT 0,
                "isEnabled" INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY ("folderID")
                    REFERENCES "snippetFolders" ("id")
                    ON DELETE CASCADE
            ) STRICT
        """)
        try execute(database, sql: """
            CREATE INDEX IF NOT EXISTS "index_snippetFolders_on_index"
            ON "snippetFolders" ("index")
        """)
        try execute(database, sql: """
            CREATE INDEX IF NOT EXISTS "index_snippets_on_folderID"
            ON "snippets" ("folderID")
        """)
        try execute(database, sql: """
            CREATE INDEX IF NOT EXISTS "index_snippets_on_index"
            ON "snippets" ("index")
        """)
        try execute(database, sql: """
            CREATE INDEX IF NOT EXISTS "index_snippets_on_folderID_index"
            ON "snippets" ("folderID", "index")
        """)
    }

    // MARK: - Helpers

    private func databasePath() throws -> String {
        var url = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            url.appendPathComponent(bundleIdentifier)
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        return url.appendingPathComponent("sqlite.db").path
    }

    private func userVersion(_ database: OpaquePointer) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func setUserVersion(_ database: OpaquePointer, version: Int) throws {
        try execute(database, sql: "PRAGMA user_version = \(version)")
    }

    private func execute(_ database: OpaquePointer, sql: String) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
        }
    }
}

// MARK: - Query Helpers

extension SQLiteStore {
    static func bindText(_ statement: OpaquePointer, index: Int, value: String) {
        sqlite3_bind_text(statement, Int32(index), value, -1, sqliteTransient)
    }

    static func bindInt(_ statement: OpaquePointer, index: Int, value: Int) {
        sqlite3_bind_int64(statement, Int32(index), Int64(value))
    }

    static func bindData(_ statement: OpaquePointer, index: Int, value: Data) {
        _ = value.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, Int32(index), bytes.baseAddress, Int32(value.count), sqliteTransient)
        }
    }

    static func columnText(_ statement: OpaquePointer, index: Int) -> String {
        String(cString: sqlite3_column_text(statement, Int32(index)))
    }

    static func columnInt(_ statement: OpaquePointer, index: Int) -> Int {
        Int(sqlite3_column_int64(statement, Int32(index)))
    }

    static func columnData(_ statement: OpaquePointer, index: Int) -> Data {
        guard let blob = sqlite3_column_blob(statement, Int32(index)) else { return Data() }
        let length = sqlite3_column_bytes(statement, Int32(index))
        return Data(bytes: blob, count: Int(length))
    }

    static func columnBool(_ statement: OpaquePointer, index: Int) -> Bool {
        sqlite3_column_int64(statement, Int32(index)) != 0
    }
}
