//
//  PasteboardHistoryRepositoryTests.swift
//
//  ReClipt
//
//  Created by Shunsuke Furubayashi on 2026/05/28.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import AppKit
import Testing
@testable import ReClipt

@MainActor
@Suite
struct PasteboardHistoryRepositoryTests {
    let repository: PasteboardHistoryRepository

    init() {
        self.repository = PasteboardHistoryRepository()
        try? SQLiteStore.shared.open()
    }

    @Test(.timeLimit(.minutes(1)))
    func saveAndFetch() async throws {
        let content = try #require(
            PasteboardContent(
                assets: [
                    PasteboardContent.Asset(type: .string, data: Data("Hello".utf8))
                ]
            )
        )

        repository.save(id: "test-id", content: content, updateAt: 1000)

        let history = repository.fetchHistory(id: "test-id")
        #expect(history != nil)
        #expect(history?.title == "Hello")
    }

    @Test
    func deleteHistory() throws {
        let content = try #require(
            PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Test".utf8))])
        )
        repository.save(id: "delete-test", content: content, updateAt: 2000)
        #expect(repository.fetchHistory(id: "delete-test") != nil)

        repository.deleteHistory(id: "delete-test")
        #expect(repository.fetchHistory(id: "delete-test") == nil)
    }

    @Test
    func deleteAll() throws {
        let content = try #require(
            PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Test".utf8))])
        )
        repository.save(id: "all-test", content: content, updateAt: 3000)
        #expect(repository.hasHistories())

        repository.deleteAll()
        #expect(!repository.hasHistories())
    }
}
