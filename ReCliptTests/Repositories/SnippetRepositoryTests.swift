//
//  SnippetRepositoryTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Testing
@testable import ReClipt

@MainActor
@Suite(.serialized)
struct SnippetRepositoryTests {
    @Test(.timeLimit(.minutes(1)))
    func insertAndFetchFolder() async throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            #expect(folder.title == "untitled folder")

            let details = repository.fetchFolderDetails()
            #expect(details.count >= 1)
        }
    }

    @Test
    func updateFolderTitle() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            repository.updateFolderTitle(folder.id, title: "Updated Title")

            let detail = repository.fetchFolderDetail(id: folder.id)
            #expect(detail?.folder.title == "Updated Title")
        }
    }

    @Test
    func insertAndFetchSnippet() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            let snippet = try #require(repository.insertSnippet(to: folder.id))
            #expect(snippet.title == "untitled snippet")

            let fetched = repository.fetchSnippet(id: snippet.id)
            #expect(fetched?.id == snippet.id)
        }
    }

    @Test
    func deleteFolder() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            repository.deleteFolder(folder.id)

            let detail = repository.fetchFolderDetail(id: folder.id)
            #expect(detail == nil)
        }
    }
}
