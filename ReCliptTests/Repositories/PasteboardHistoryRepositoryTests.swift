//
//  PasteboardHistoryRepositoryTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import AppKit
import Testing
@testable import ReClipt

@MainActor
@Suite(.serialized)
struct PasteboardHistoryRepositoryTests {
    @Test(.timeLimit(.minutes(1)))
    func saveAndFetch() async throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
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
    }

    @Test
    func deleteHistory() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let content = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Test".utf8))])
            )
            repository.save(id: "delete-test", content: content, updateAt: 2000)
            #expect(repository.fetchHistory(id: "delete-test") != nil)

            repository.deleteHistory(id: "delete-test")
            #expect(repository.fetchHistory(id: "delete-test") == nil)
        }
    }

    @Test
    func deleteAll() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let content = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Test".utf8))])
            )
            repository.save(id: "all-test", content: content, updateAt: 3000)
            #expect(repository.hasHistories())

            repository.deleteAll()
            #expect(!repository.hasHistories())
        }
    }

    @Test
    func fetchHistoryDetailsHonorsOrderingLimitAndOffset() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            for index in 0..<5 {
                let content = try #require(
                    PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Item \(index)".utf8))])
                )
                repository.save(id: "item-\(index)", content: content, updateAt: 1000 + index)
            }

            let ascendingPage = repository.fetchHistoryDetails(
                ascending: true,
                includesThumbnailAsset: false,
                limit: 2,
                offset: 1
            )
            let descendingPage = repository.fetchHistoryDetails(
                ascending: false,
                includesThumbnailAsset: false,
                limit: 3,
                offset: 0
            )

            #expect(ascendingPage.map(\.history.id) == ["item-1", "item-2"])
            #expect(descendingPage.map(\.history.id) == ["item-4", "item-3", "item-2"])
            #expect(ascendingPage.allSatisfy { $0.thumbnailAsset == nil })
        }
    }

    @Test
    func fetchHistoryDetailsIncludesThumbnailAssetWhenRequested() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let content = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("#336699".utf8))])
            )
            repository.save(id: "color", content: content, updateAt: 1000)

            let withoutThumbnail = repository.fetchHistoryDetails(
                ascending: true,
                includesThumbnailAsset: false,
                limit: 1,
                offset: 0
            )
            let withThumbnail = repository.fetchHistoryDetails(
                ascending: true,
                includesThumbnailAsset: true,
                limit: 1,
                offset: 0
            )

            #expect(withoutThumbnail.first?.thumbnailAsset == nil)
            #expect(withThumbnail.first?.thumbnailAsset?.kind == .colorCode)
            #expect(withThumbnail.first?.thumbnailAsset?.data.isEmpty == false)
        }
    }

    @Test
    func deleteAllCascadesAssetsAndThumbnails() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let content = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("#112233".utf8))])
            )
            repository.save(id: "cascade", content: content, updateAt: 1000)
            #expect(repository.fetchContent(id: "cascade") != nil)
            #expect(repository.fetchHistoryDetails(ascending: true, includesThumbnailAsset: true, limit: 1, offset: 0).first?.thumbnailAsset != nil)

            repository.deleteAll()

            #expect(repository.fetchHistory(id: "cascade") == nil)
            #expect(repository.fetchContent(id: "cascade") == nil)
            #expect(repository.fetchHistoryDetails(ascending: true, includesThumbnailAsset: true, limit: 1, offset: 0).isEmpty)
        }
    }

    @Test
    func deleteOverflowingHistoriesKeepsNewestItems() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            for index in 0..<5 {
                let content = try #require(
                    PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Overflow \(index)".utf8))])
                )
                repository.save(id: "overflow-\(index)", content: content, updateAt: 1000 + index)
            }

            repository.deleteOverflowingHistories(maxHistorySize: 2)

            let remaining = repository.fetchHistoryDetails(
                ascending: false,
                includesThumbnailAsset: false,
                limit: 10,
                offset: 0
            )
            #expect(remaining.map(\.history.id) == ["overflow-4", "overflow-3"])
            #expect(repository.count() == 2)
        }
    }

    @Test
    func menuManagerLazyLoadsHistorySubmenusOnce() throws {
        try TestSQLiteStore.withCleanStore {
            let defaults = try #require(UserDefaults(suiteName: "MenuManagerLazyLoadsHistorySubmenusOnce"))
            defaults.removePersistentDomain(forName: "MenuManagerLazyLoadsHistorySubmenusOnce")
            defaults.set(2, forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
            defaults.set(2, forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
            defaults.set(10, forKey: Constants.UserDefaults.maxHistorySize)
            defaults.set(20, forKey: Constants.UserDefaults.maxMenuItemTitleLength)
            defaults.set(false, forKey: Constants.UserDefaults.reorderClipsAfterPasting)
            defaults.set(false, forKey: Constants.UserDefaults.showIconInTheMenu)
            defaults.set(false, forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
            defaults.set(false, forKey: Constants.UserDefaults.addNumericKeyEquivalents)
            defaults.set(false, forKey: Constants.UserDefaults.showToolTipOnMenuItem)
            AppEnvironment.push(defaults: defaults)
            defer {
                _ = AppEnvironment.popLast()
                defaults.removePersistentDomain(forName: "MenuManagerLazyLoadsHistorySubmenusOnce")
            }

            let repository = PasteboardHistoryRepository()
            for index in 0..<5 {
                let content = try #require(
                    PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Lazy \(index)".utf8))])
                )
                repository.save(id: "lazy-\(index)", content: content, updateAt: 1000 + index)
            }

            let menuManager = MenuManager()
            menuManager.testBuildMenus()

            let mainMenu = try #require(menuManager.testMainMenu)
            let firstFolderItem = try #require(mainMenu.items.first { $0.title == "3 - 4" })
            let firstFolderMenu = try #require(firstFolderItem.submenu)
            #expect(firstFolderMenu.numberOfItems == 0)

            menuManager.menuNeedsUpdate(firstFolderMenu)

            #expect(firstFolderMenu.items.map(\.title) == ["Lazy 2", "Lazy 3"])
            #expect(firstFolderMenu.items.map { $0.representedObject as? String } == ["lazy-2", "lazy-3"])

            menuManager.menuNeedsUpdate(firstFolderMenu)

            #expect(firstFolderMenu.items.map(\.title) == ["Lazy 2", "Lazy 3"])
        }
    }
}
