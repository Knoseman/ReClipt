//
//  SnippetRepositoryTests.swift
//
//  ReClipt
//
//  Created by Shunsuke Furubayashi on 2026/05/26.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Testing
@testable import ReClipt

@MainActor
@Suite
struct SnippetRepositoryTests {
    let repository: SnippetRepository

    init() {
        self.repository = SnippetRepository()
        try? SQLiteStore.shared.open()
    }

    @Test(.timeLimit(.minutes(1)))
    func insertAndFetchFolder() async throws {
        let folder = try #require(repository.insertFolder())
        #expect(folder.title == "untitled folder")

        let details = repository.fetchFolderDetails()
        #expect(details.count >= 1)
    }

    @Test
    func updateFolderTitle() throws {
        let folder = try #require(repository.insertFolder())
        repository.updateFolderTitle(folder.id, title: "Updated Title")

        let detail = repository.fetchFolderDetail(id: folder.id)
        #expect(detail?.folder.title == "Updated Title")
    }

    @Test
    func insertAndFetchSnippet() throws {
        let folder = try #require(repository.insertFolder())
        let snippet = try #require(repository.insertSnippet(to: folder.id))
        #expect(snippet.title == "untitled snippet")

        let fetched = repository.fetchSnippet(id: snippet.id)
        #expect(fetched?.id == snippet.id)
    }

    @Test
    func deleteFolder() throws {
        let folder = try #require(repository.insertFolder())
        repository.deleteFolder(folder.id)

        let detail = repository.fetchFolderDetail(id: folder.id)
        #expect(detail == nil)
    }
}
