//
//  SnippetRepositoryTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Foundation
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
            #expect(folder.index == 0)

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
            #expect(snippet.index == 0)

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

    @Test
    func updateFolderEnabledState() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())

            repository.updateFolderIsEnabled(folder.id, isEnabled: false)

            let detail = try #require(repository.fetchFolderDetail(id: folder.id))
            #expect(!detail.folder.isEnabled)
        }
    }

    @Test
    func updateSnippetFields() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            let snippet = try #require(repository.insertSnippet(to: folder.id))

            repository.updateSnippetTitle(snippet.id, title: "Updated Snippet")
            repository.updateSnippetContent(snippet.id, content: "updated snippet body")
            repository.updateSnippetIsEnabled(snippet.id, isEnabled: false)

            let fetched = try #require(repository.fetchSnippet(id: snippet.id))
            #expect(fetched.title == "Updated Snippet")
            #expect(fetched.content == "updated snippet body")
            #expect(!fetched.isEnabled)
        }
    }

    @Test
    func deleteSnippetLeavesFolderInPlace() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            let snippet = try #require(repository.insertSnippet(to: folder.id))

            repository.deleteSnippet(snippet.id)

            #expect(repository.fetchSnippet(id: snippet.id) == nil)
            let detail = try #require(repository.fetchFolderDetail(id: folder.id))
            #expect(detail.snippets.isEmpty)
        }
    }

    @Test
    func updateFolderIndexesControlsFetchOrder() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let first = try #require(repository.insertFolder())
            let second = try #require(repository.insertFolder())
            let third = try #require(repository.insertFolder())

            repository.updateFolderIndexes([third.id, first.id, second.id])

            let details = repository.fetchFolderDetails()
            #expect(details.map(\.folder.id) == [third.id, first.id, second.id])
            #expect(details.map(\.folder.index) == [0, 1, 2])
        }
    }

    @Test
    func updateSnippetIndexesControlsFolderOrder() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let folder = try #require(repository.insertFolder())
            let first = try #require(repository.insertSnippet(to: folder.id))
            let second = try #require(repository.insertSnippet(to: folder.id))
            let third = try #require(repository.insertSnippet(to: folder.id))

            repository.updateSnippetIndexes([third.id, first.id, second.id])

            let detail = try #require(repository.fetchFolderDetail(id: folder.id))
            #expect(detail.snippets.map(\.id) == [third.id, first.id, second.id])
            #expect(detail.snippets.map(\.index) == [0, 1, 2])
        }
    }

    @Test
    func moveSnippetToAnotherFolderUpdatesFolderAndOrder() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let sourceFolder = try #require(repository.insertFolder())
            let destinationFolder = try #require(repository.insertFolder())
            let moved = try #require(repository.insertSnippet(to: sourceFolder.id))
            let existing = try #require(repository.insertSnippet(to: destinationFolder.id))

            repository.moveSnippet(
                moved.id,
                to: destinationFolder.id,
                snippetIDs: [moved.id, existing.id]
            )

            let sourceDetail = try #require(repository.fetchFolderDetail(id: sourceFolder.id))
            let destinationDetail = try #require(repository.fetchFolderDetail(id: destinationFolder.id))
            #expect(sourceDetail.snippets.isEmpty)
            #expect(destinationDetail.snippets.map(\.id) == [moved.id, existing.id])
            #expect(destinationDetail.snippets.map(\.folderID) == [destinationFolder.id, destinationFolder.id])
            #expect(destinationDetail.snippets.map(\.index) == [0, 1])
        }
    }

    @Test
    func insertTransferFoldersPreservesEditableSnippetState() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let transferFolders = [
                SnippetTransferFolder(
                    id: UUID(),
                    title: "Imported",
                    index: 4,
                    isEnabled: false,
                    snippets: [
                        SnippetTransferSnippet(
                            id: UUID(),
                            title: "API Key",
                            content: "secret",
                            index: 3,
                            isEnabled: false
                        )
                    ]
                )
            ]

            let importedDetails = try #require(repository.insertTransferFolders(transferFolders))

            #expect(importedDetails.count == 1)
            let detail = try #require(repository.fetchFolderDetail(id: importedDetails[0].folder.id))
            #expect(detail.folder.title == "Imported")
            #expect(detail.folder.index == 4)
            #expect(!detail.folder.isEnabled)
            #expect(detail.snippets.count == 1)
            #expect(detail.snippets[0].title == "API Key")
            #expect(detail.snippets[0].content == "secret")
            #expect(detail.snippets[0].index == 3)
            #expect(!detail.snippets[0].isEnabled)
            #expect(detail.snippets[0].folderID == detail.folder.id)
        }
    }

    @Test
    func searchFolderDetailsUsesFullTextIndexAndTracksChanges() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = SnippetRepository()
            let commonFolder = try #require(repository.insertFolder())
            repository.updateFolderTitle(commonFolder.id, title: "Common")
            let commonSnippet = try #require(repository.insertSnippet(to: commonFolder.id))
            repository.updateSnippetTitle(commonSnippet.id, title: "Email")
            repository.updateSnippetContent(commonSnippet.id, content: "hello@example.com")

            let workFolder = try #require(repository.insertFolder())
            repository.updateFolderTitle(workFolder.id, title: "Work")
            let deploySnippet = try #require(repository.insertSnippet(to: workFolder.id))
            repository.updateSnippetTitle(deploySnippet.id, title: "Deploy")
            repository.updateSnippetContent(deploySnippet.id, content: "needle token")
            let notesSnippet = try #require(repository.insertSnippet(to: workFolder.id))
            repository.updateSnippetTitle(notesSnippet.id, title: "Notes")
            repository.updateSnippetContent(notesSnippet.id, content: "general")

            let snippetMatches = repository.searchFolderDetails(query: "need")
            #expect(snippetMatches.map(\.folder.id) == [workFolder.id])
            #expect(snippetMatches.first?.snippets.map(\.id) == [deploySnippet.id])

            let folderMatches = repository.searchFolderDetails(query: "common")
            #expect(folderMatches.map(\.folder.id) == [commonFolder.id])
            #expect(folderMatches.first?.snippets.map(\.id) == [commonSnippet.id])

            repository.updateSnippetContent(deploySnippet.id, content: "changed token")
            #expect(repository.searchFolderDetails(query: "need").isEmpty)
            #expect(repository.searchFolderDetails(query: "changed").first?.snippets.map(\.id) == [deploySnippet.id])

            repository.deleteFolder(commonFolder.id)
            #expect(repository.searchFolderDetails(query: "common").isEmpty)
        }
    }
}
