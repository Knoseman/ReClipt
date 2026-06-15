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

    @Test(.timeLimit(.minutes(1)))
    func saveUsesFileNameForFileHistoryTitle() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let content = try #require(
                PasteboardContent(
                    assets: [
                        fileURLAsset("/tmp/report.pdf")
                    ]
                )
            )

            repository.save(id: "file-id", content: content, updateAt: 1000)

            let history = repository.fetchHistory(id: "file-id")
            #expect(history?.title == "report.pdf")
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
    func searchHistoryDetailsUsesFullTextIndexAndTracksUpdates() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let first = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Alpha token".utf8))])
            )
            let second = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Beta needle".utf8))])
            )
            let updated = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Beta changed".utf8))])
            )

            repository.save(id: "alpha", content: first, updateAt: 1000)
            repository.save(id: "beta", content: second, updateAt: 2000)

            let initialMatches = repository.searchHistoryDetails(
                query: "need",
                ascending: false,
                includesThumbnailAsset: false,
                limit: 10,
                offset: 0
            )
            #expect(initialMatches.map(\.history.id) == ["beta"])

            repository.save(id: "beta", content: updated, updateAt: 3000)

            #expect(repository.searchHistoryDetails(
                query: "need",
                ascending: false,
                includesThumbnailAsset: false,
                limit: 10,
                offset: 0
            ).isEmpty)
            #expect(repository.searchHistoryDetails(
                query: "changed",
                ascending: false,
                includesThumbnailAsset: false,
                limit: 10,
                offset: 0
            ).map(\.history.id) == ["beta"])
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
            let defaults = try pushMenuTestEnvironment(
                suiteName: "MenuManagerLazyLoadsHistorySubmenusOnce",
                inlineItems: 2,
                itemsPerFolder: 2,
                maxHistorySize: 10,
                showIcons: false,
                showNumbers: false,
                enableNumericShortcuts: false
            )
            defer { popMenuTestEnvironment(defaults, suiteName: "MenuManagerLazyLoadsHistorySubmenusOnce") }

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

    @Test
    func menuManagerHonorsNumberAndShortcutSettings() throws {
        try TestSQLiteStore.withCleanStore {
            let defaults = try pushMenuTestEnvironment(
                suiteName: "MenuManagerHonorsNumberAndShortcutSettings",
                inlineItems: 3,
                itemsPerFolder: 10,
                maxHistorySize: 10,
                showIcons: false,
                showNumbers: true,
                enableNumericShortcuts: true
            )
            defer { popMenuTestEnvironment(defaults, suiteName: "MenuManagerHonorsNumberAndShortcutSettings") }

            try saveHistories(titles: ["One", "Two", "Three"])

            let menuManager = MenuManager()
            menuManager.testBuildMenus()

            let historyItems = try historyItems(in: #require(menuManager.testMainMenu))
            #expect(historyItems.map(\.title) == ["1. One", "2. Two", "3. Three"])
            #expect(historyItems.map(\.keyEquivalent) == ["1", "2", "3"])
        }
    }

    @Test
    func menuManagerHonorsHiddenNumbersAndDisabledShortcuts() throws {
        try TestSQLiteStore.withCleanStore {
            let defaults = try pushMenuTestEnvironment(
                suiteName: "MenuManagerHonorsHiddenNumbersAndDisabledShortcuts",
                inlineItems: 2,
                itemsPerFolder: 10,
                maxHistorySize: 10,
                showIcons: false,
                showNumbers: false,
                enableNumericShortcuts: false
            )
            defer { popMenuTestEnvironment(defaults, suiteName: "MenuManagerHonorsHiddenNumbersAndDisabledShortcuts") }

            try saveHistories(titles: ["Alpha", "Beta"])

            let menuManager = MenuManager()
            menuManager.testBuildMenus()

            let historyItems = try historyItems(in: #require(menuManager.testMainMenu))
            #expect(historyItems.map(\.title) == ["Alpha", "Beta"])
            #expect(historyItems.map(\.keyEquivalent) == ["", ""])
        }
    }

    @Test
    func menuManagerHonorsIconVisibilityForHistoryFoldersAndSnippets() throws {
        try TestSQLiteStore.withCleanStore {
            let defaults = try pushMenuTestEnvironment(
                suiteName: "MenuManagerHonorsIconVisibilityForHistoryFoldersAndSnippets",
                inlineItems: 0,
                itemsPerFolder: 2,
                maxHistorySize: 10,
                showIcons: true,
                showNumbers: false,
                enableNumericShortcuts: false
            )
            defer { popMenuTestEnvironment(defaults, suiteName: "MenuManagerHonorsIconVisibilityForHistoryFoldersAndSnippets") }

            try saveHistories(titles: ["Foldered One", "Foldered Two", "Foldered Three"])
            let snippetRepository = SnippetRepository()
            let folder = try #require(snippetRepository.insertFolder())
            snippetRepository.updateFolderTitle(folder.id, title: "Snippets")
            let snippet = try #require(snippetRepository.insertSnippet(to: folder.id))
            snippetRepository.updateSnippetTitle(snippet.id, title: "Snippet One")

            let menuManager = MenuManager()
            menuManager.testBuildMenus()

            let mainMenu = try #require(menuManager.testMainMenu)
            let historyFolderItem = try #require(mainMenu.items.first { $0.title == "1 - 2" })
            let snippetFolderItem = try #require(mainMenu.items.first { $0.title == "Snippets" })
            let snippetItem = try #require(snippetFolderItem.submenu?.items.first { $0.title == "Snippet One" })

            #expect(historyFolderItem.image != nil)
            #expect(snippetFolderItem.image != nil)
            #expect(snippetItem.image != nil)
        }
    }

    @Test
    func menuManagerShowsFileNamesAndTypeIconsForHistoryItems() throws {
        try TestSQLiteStore.withCleanStore {
            let defaults = try pushMenuTestEnvironment(
                suiteName: "MenuManagerShowsFileNamesAndTypeIconsForHistoryItems",
                inlineItems: 2,
                itemsPerFolder: 10,
                maxHistorySize: 10,
                showIcons: true,
                showNumbers: false,
                enableNumericShortcuts: false
            )
            defer { popMenuTestEnvironment(defaults, suiteName: "MenuManagerShowsFileNamesAndTypeIconsForHistoryItems") }

            let repository = PasteboardHistoryRepository()
            let fileContent = try #require(
                PasteboardContent(assets: [fileURLAsset("/tmp/report.pdf")])
            )
            let textContent = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Plain text".utf8))])
            )
            repository.save(id: "file", content: fileContent, updateAt: 1000)
            repository.save(id: "text", content: textContent, updateAt: 1001)

            let menuManager = MenuManager()
            menuManager.testBuildMenus()

            let historyItems = try historyItems(in: #require(menuManager.testMainMenu))
            #expect(historyItems.map(\.title) == ["report.pdf", "Plain text"])
            #expect(historyItems.allSatisfy { $0.image != nil })
        }
    }

    @Test
    func fetchBackupHistoryItemsIncludesAssetsAndThumbnailInStableOrder() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let newer = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("#336699".utf8))])
            )
            let older = try #require(
                PasteboardContent(assets: [
                    PasteboardContent.Asset(type: .string, data: Data("First".utf8)),
                    fileURLAsset("/tmp/report.pdf")
                ])
            )

            repository.save(id: "newer", content: newer, updateAt: 2000)
            repository.save(id: "older", content: older, updateAt: 1000)

            let items = repository.fetchBackupHistoryItems()

            #expect(items.map(\.id) == ["older", "newer"])
            #expect(items[0].assets.map(\.index) == [0, 1])
            #expect(items[0].assets.map(\.pasteboardType) == [NSPasteboard.PasteboardType.string.rawValue, NSPasteboard.PasteboardType.fileURL.rawValue])
            #expect(items[0].assets[0].data == Data("First".utf8))
            #expect(items[1].thumbnail?.kind == PasteboardHistoryThumbnailAsset.Kind.colorCode.rawValue)
            #expect(items[1].thumbnail?.data.isEmpty == false)
        }
    }

    @Test
    func restoreBackupHistoryItemsRecreatesContentAndPostsNotification() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            var didNotify = false
            let token = NotificationCenter.default.addObserver(
                forName: PasteboardHistoryRepository.historyDidChangeNotification,
                object: nil,
                queue: nil
            ) { _ in
                didNotify = true
            }
            defer { NotificationCenter.default.removeObserver(token) }

            try repository.restoreBackupHistoryItems([
                BackupHistoryItem(
                    id: "restored",
                    title: "Restored title",
                    pasteboardTypes: [NSPasteboard.PasteboardType.string.rawValue],
                    updateAt: 1234,
                    deviceID: "device-a",
                    assets: [
                        BackupHistoryAsset(index: 0, pasteboardType: NSPasteboard.PasteboardType.string.rawValue, data: Data("Restored body".utf8))
                    ],
                    thumbnail: BackupHistoryThumbnail(kind: PasteboardHistoryThumbnailAsset.Kind.colorCode.rawValue, data: Data([1, 2, 3]))
                )
            ])

            let history = try #require(repository.fetchHistory(id: "restored"))
            let content = try #require(repository.fetchContent(id: "restored"))
            let detail = try #require(repository.fetchHistoryDetails(ascending: true, includesThumbnailAsset: true, limit: 1, offset: 0).first)
            #expect(history.title == "Restored title")
            #expect(history.pasteboardTypes == [.string])
            #expect(history.updateAt == 1234)
            #expect(history.deviceID == "device-a")
            #expect(content.assets == [PasteboardContent.Asset(type: .string, data: Data("Restored body".utf8))])
            #expect(detail.thumbnailAsset?.data == Data([1, 2, 3]))
            #expect(didNotify)
        }
    }

    @Test
    func restoreBackupHistoryItemsUpdatesExistingHistoryWithoutDuplicating() throws {
        try TestSQLiteStore.withCleanStore {
            let repository = PasteboardHistoryRepository()
            let original = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Original".utf8))])
            )
            repository.save(id: "same-id", content: original, updateAt: 1000)

            try repository.restoreBackupHistoryItems([
                BackupHistoryItem(
                    id: "same-id",
                    title: "Updated",
                    pasteboardTypes: [NSPasteboard.PasteboardType.string.rawValue],
                    updateAt: 3000,
                    deviceID: nil,
                    assets: [
                        BackupHistoryAsset(index: 0, pasteboardType: NSPasteboard.PasteboardType.string.rawValue, data: Data("Updated".utf8))
                    ],
                    thumbnail: nil
                )
            ])

            let history = try #require(repository.fetchHistory(id: "same-id"))
            let content = try #require(repository.fetchContent(id: "same-id"))
            #expect(repository.count() == 1)
            #expect(history.title == "Updated")
            #expect(history.updateAt == 3000)
            #expect(content.stringValue == "Updated")
            #expect(repository.searchHistoryDetails(query: "Original", ascending: true, includesThumbnailAsset: false, limit: 10, offset: 0).isEmpty)
            #expect(repository.searchHistoryDetails(query: "Updated", ascending: true, includesThumbnailAsset: false, limit: 10, offset: 0).map(\.history.id) == ["same-id"])
        }
    }
}

private extension PasteboardHistoryRepositoryTests {
    func pushMenuTestEnvironment(
        suiteName: String,
        inlineItems: Int,
        itemsPerFolder: Int,
        maxHistorySize: Int,
        showIcons: Bool,
        showNumbers: Bool,
        enableNumericShortcuts: Bool
    ) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(inlineItems, forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
        defaults.set(itemsPerFolder, forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
        defaults.set(maxHistorySize, forKey: Constants.UserDefaults.maxHistorySize)
        defaults.set(20, forKey: Constants.UserDefaults.maxMenuItemTitleLength)
        defaults.set(false, forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        defaults.set(showIcons, forKey: Constants.UserDefaults.showIconInTheMenu)
        defaults.set(false, forKey: Constants.UserDefaults.showImageInTheMenu)
        defaults.set(false, forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        defaults.set(showNumbers, forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        defaults.set(false, forKey: Constants.UserDefaults.menuItemsTitleStartWithZero)
        defaults.set(enableNumericShortcuts, forKey: Constants.UserDefaults.addNumericKeyEquivalents)
        defaults.set(false, forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        defaults.set(true, forKey: Constants.UserDefaults.addClearHistoryMenuItem)
        AppEnvironment.push(defaults: defaults)
        return defaults
    }

    func popMenuTestEnvironment(_ defaults: UserDefaults, suiteName: String) {
        _ = AppEnvironment.popLast()
        defaults.removePersistentDomain(forName: suiteName)
    }

    func saveHistories(titles: [String]) throws {
        let repository = PasteboardHistoryRepository()
        for (index, title) in titles.enumerated() {
            let content = try #require(
                PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data(title.utf8))])
            )
            repository.save(id: "menu-\(index)", content: content, updateAt: 1000 + index)
        }
    }

    func historyItems(in menu: NSMenu) throws -> [NSMenuItem] {
        let historyLabelIndex = try #require(menu.items.firstIndex { $0.title == String(localized: "History") })
        let firstNonHistoryIndex = menu.items[(historyLabelIndex + 1)...].firstIndex { item in
            item.isSeparatorItem || item.submenu != nil || item.action != #selector(AppDelegate.selectHistoryMenuItem(_:))
        } ?? menu.numberOfItems
        return Array(menu.items[(historyLabelIndex + 1)..<firstNonHistoryIndex])
    }

    func fileURLAsset(_ path: String) -> PasteboardContent.Asset {
        PasteboardContent.Asset(
            type: .fileURL,
            data: URL(fileURLWithPath: path).dataRepresentation
        )
    }
}
