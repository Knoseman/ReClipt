//
//  MenuManager.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa
import Foundation

final class MenuManager: NSObject {

    // MARK: - Properties
    // Menus
    fileprivate var mainMenu: NSMenu?
    fileprivate var historyMenu: NSMenu?
    fileprivate var snippetMenu: NSMenu?
    // StatusMenu
    fileprivate var statusItem: NSStatusItem?
    // Icon Cache
    fileprivate let folderIcon = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? NSImage(size: .zero)
    fileprivate let snippetIcon = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil) ?? NSImage(size: .zero)
    // Other
    fileprivate let notificationCenter = NotificationCenter.default
    fileprivate let kMaxKeyEquivalents = 10
    fileprivate let shortenSymbol = "..."

    private let pasteboardHistoryRepository = PasteboardHistoryRepository()
    private let snippetRepository = SnippetRepository()
    private var snippetFolderDetails = [SnippetFolderDetail]()
    private var historyObserver: NSObjectProtocol?
    private var snippetObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var currentStatusType: StatusType = .none
    private var isUpdatingStatusItem = false
    private var rebuildMenuTimer: Timer?

    // MARK: - Enum Values
    enum StatusType: Int {
        case none, black, white
    }

    // MARK: - Initialize
    override init() {
        super.init()
        folderIcon.isTemplate = true
        folderIcon.size = NSSize(width: 15, height: 13)
        snippetIcon.isTemplate = true
        snippetIcon.size = NSSize(width: 12, height: 13)
    }

    func setup() {
        bind()
    }

    var hasVisibleStatusItem: Bool {
        statusItem != nil
    }

    deinit {
        if let observer = historyObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = snippetObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = defaultsObserver {
            notificationCenter.removeObserver(observer)
        }
    }

}

// MARK: - Popup Menu
extension MenuManager {
    func popUpMenu(_ type: MenuType) {
        let menu: NSMenu?
        switch type {
        case .main:
            menu = mainMenu
        case .history:
            menu = historyMenu
        case .snippet:
            menu = snippetMenu
        }
        menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func popUpSnippetFolder(_ folderDetail: SnippetFolderDetail) {
        let folderMenu = NSMenu(title: folderDetail.folder.title)
        // Folder title
        let labelItem = NSMenuItem(title: folderDetail.folder.title, action: nil)
        labelItem.isEnabled = false
        folderMenu.addItem(labelItem)
        // Snippets
        var index = firstIndexOfMenuItems()
        folderDetail.snippets
            .filter { $0.isEnabled }
            .forEach { snippet in
                let subMenuItem = makeSnippetMenuItem(snippet, listNumber: index)
                folderMenu.addItem(subMenuItem)
                index += 1
            }
        folderMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - Binding
private extension MenuManager {
    func bind() {
        // History changes
        historyObserver = notificationCenter.addObserver(
            forName: PasteboardHistoryRepository.historyDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleMenuRebuild()
        }

        // Snippet changes
        snippetObserver = notificationCenter.addObserver(
            forName: SnippetRepository.snippetsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.snippetFolderDetails = self?.snippetRepository.fetchFolderDetails() ?? []
            self?.scheduleMenuRebuild()
        }
        snippetFolderDetails = snippetRepository.fetchFolderDetails()

        // Menu icon
        updateStatusItem()

        // Initial menu build
        createMainMenu()

        // Observe UserDefaults changes for menu settings
        defaultsObserver = notificationCenter.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard !self.isUpdatingStatusItem else { return }
            self.scheduleMenuRebuild()
            self.updateStatusItem()
        }
    }

    private func scheduleMenuRebuild() {
        rebuildMenuTimer?.invalidate()
        rebuildMenuTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.createMainMenu()
        }
    }

    func updateStatusItem() {
        let key = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.showStatusItem)
        changeStatusItem(StatusType(rawValue: key) ?? .black)
    }
}

// MARK: - Menus
private extension MenuManager {
     func createMainMenu() {
        mainMenu = NSMenu(title: Constants.Application.name)
        mainMenu?.delegate = self
        historyMenu = NSMenu(title: Constants.Menu.history)
        historyMenu?.delegate = self
        snippetMenu = NSMenu(title: Constants.Menu.snippet)

        addHistoryItems(mainMenu!)
        addHistoryItems(historyMenu!)

        addSnippetItems(mainMenu!, separateMenu: true, details: snippetFolderDetails)
        addSnippetItems(snippetMenu!, separateMenu: false, details: snippetFolderDetails)

        mainMenu?.addItem(NSMenuItem.separator())

        if AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.addClearHistoryMenuItem) {
            let clearHistoryItem = NSMenuItem(title: String(localized: "Clear History"), action: #selector(AppDelegate.clearAllHistory))
            clearHistoryItem.target = NSApp.delegate
            mainMenu?.addItem(clearHistoryItem)
        }

        let editSnippetsItem = NSMenuItem(title: String(localized: "Edit Snippets"), action: #selector(AppDelegate.showSnippetEditorWindow))
        editSnippetsItem.target = NSApp.delegate
        mainMenu?.addItem(editSnippetsItem)
        let preferencesItem = NSMenuItem(title: String(localized: "Preferences"), action: #selector(AppDelegate.showPreferenceWindow))
        preferencesItem.target = NSApp.delegate
        mainMenu?.addItem(preferencesItem)
        mainMenu?.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: String(localized: "Quit ReClipt"), action: #selector(AppDelegate.terminate))
        quitItem.target = NSApp.delegate
        mainMenu?.addItem(quitItem)

        statusItem?.menu = mainMenu
    }

    func menuItemTitle(_ title: String, listNumber: NSInteger, isMarkWithNumber: Bool) -> String {
        return (isMarkWithNumber) ? "\(listNumber). \(title)" : title
    }

    func makeSubmenuItem(_ count: Int, start: Int, end: Int, numberOfItems: Int) -> NSMenuItem {
        var count = count
        if start == 0 {
            count -= 1
        }
        var lastNumber = count + numberOfItems
        if end < lastNumber {
            lastNumber = end
        }
        let menuItemTitle = "\(count + 1) - \(lastNumber)"
        let item = makeSubmenuItem(menuItemTitle)
        item.representedObject = HistorySubmenuInfo(offset: count, limit: numberOfItems)
        return item
    }

    func makeSubmenuItem(_ title: String) -> NSMenuItem {
        let subMenu = NSMenu(title: title)
        subMenu.delegate = self
        let subMenuItem = NSMenuItem(title: title, action: nil)
        subMenuItem.submenu = subMenu
        subMenuItem.image = (AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)) ? folderIcon : nil
        return subMenuItem
    }

    func incrementListNumber(_ listNumber: NSInteger, max: NSInteger, start: NSInteger) -> NSInteger {
        var listNumber = listNumber + 1
        if listNumber == max && max == 10 && start == 1 {
            listNumber = 0
        }
        return listNumber
    }

    func trimTitle(_ title: String?) -> String {
        if title == nil { return "" }
        let theString = title!.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        let aRange = NSRange(location: 0, length: 0)
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        theString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: aRange)

        var titleString = (lineEnd == theString.length) ? theString as String : theString.substring(to: contentsEnd)

        var maxMenuItemTitleLength = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxMenuItemTitleLength)
        if maxMenuItemTitleLength < shortenSymbol.count {
            maxMenuItemTitleLength = shortenSymbol.count
        }

        if titleString.utf16.count > maxMenuItemTitleLength {
            titleString = (titleString as NSString).substring(to: maxMenuItemTitleLength - shortenSymbol.count) + shortenSymbol
        }

        return titleString as String
    }
}

// MARK: - Clips
private extension MenuManager {
    func addHistoryItems(_ menu: NSMenu) {
        let placeInLine = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
        let placeInsideFolder = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
        let maxHistory = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxHistorySize)

        // History title
        let labelItem = NSMenuItem(title: String(localized: "History"), action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        let totalCount = min(pasteboardHistoryRepository.count(), maxHistory)
        guard totalCount > 0 else { return }

        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let showsMenuItemIcons = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)
        let isShowImage = showsMenuItemIcons && AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = showsMenuItemIcons && AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)

        // Inline items
        let inlineLimit = min(placeInLine, totalCount)
        if inlineLimit > 0 {
            let historyDetails = pasteboardHistoryRepository.fetchHistoryDetails(
                ascending: ascending,
                includesThumbnailAsset: isShowImage || isShowColorCode,
                limit: inlineLimit,
                offset: 0
            )
            let firstIndex = firstIndexOfMenuItems()
            var listNumber = firstIndex
            for (i, detail) in historyDetails.enumerated() {
                let menuItem = makeHistoryMenuItem(detail, index: i, listNumber: listNumber)
                menu.addItem(menuItem)
                listNumber = incrementListNumber(listNumber, max: placeInLine, start: firstIndex)
            }
        }

        // Folders for the rest
        if totalCount > placeInLine && placeInsideFolder > 0 {
            let firstIndex = firstIndexOfMenuItems()
            var offset = placeInLine
            while offset < totalCount {
                let subMenuItem = makeSubmenuItem(offset, start: firstIndex, end: totalCount, numberOfItems: placeInsideFolder)
                menu.addItem(subMenuItem)
                offset += placeInsideFolder
            }
        }
    }

    func makeHistoryMenuItem(_ historyDetail: PasteboardHistoryDetail, index: Int, listNumber: Int) -> NSMenuItem {
        let history = historyDetail.history
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowToolTip = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        let showsMenuItemIcons = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)
        let isShowImage = showsMenuItemIcons && AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = showsMenuItemIcons && AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        let addNumbericKeyEquivalents = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.addNumericKeyEquivalents)

        var keyEquivalent = ""

        if addNumbericKeyEquivalents && index < kMaxKeyEquivalents {
            let isStartFromZero = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsTitleStartWithZero)

            var shortCutNumber = (isStartFromZero) ? index : index + 1
            if shortCutNumber == kMaxKeyEquivalents {
                shortCutNumber = 0
            }
            keyEquivalent = "\(shortCutNumber)"
        }

        let primaryPboardType = history.primaryType
        let clipString = history.title
        let title = trimTitle(clipString)
        let titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectHistoryMenuItem(_:)), keyEquivalent: keyEquivalent)
        menuItem.target = NSApp.delegate
        menuItem.representedObject = history.id

        if isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxLengthOfToolTip)
            let toIndex = (clipString.count < maxLengthOfToolTip) ? clipString.count : maxLengthOfToolTip
            menuItem.toolTip = (clipString as NSString).substring(to: toIndex)
        }

        if primaryPboardType == .png || primaryPboardType == .tiff || primaryPboardType == .deprecatedTIFF {
            menuItem.title = menuItemTitle("(Image)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
        } else if primaryPboardType == .pdf || primaryPboardType == .deprecatedPDF {
            menuItem.title = menuItemTitle("(PDF)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
        } else if primaryPboardType == .fileURL || primaryPboardType == .deprecatedFilenames {
            menuItem.title = menuItemTitle("(Files)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
        }

        if isShowImage || isShowColorCode,
           let thumbnailAsset = historyDetail.thumbnailAsset,
           let image = NSImage(data: thumbnailAsset.data),
           (thumbnailAsset.kind == .image && isShowImage) || (thumbnailAsset.kind == .colorCode && isShowColorCode) {
            let width = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.thumbnailWidth)
            let height = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.thumbnailHeight)
            menuItem.image = image.aspectFitImage(CGFloat(width), CGFloat(height))
        }

        return menuItem
    }
}

// MARK: - Snippets
private extension MenuManager {
    func addSnippetItems(_ menu: NSMenu, separateMenu: Bool, details: [SnippetFolderDetail]) {
        guard !details.isEmpty else { return }

        if separateMenu {
            menu.addItem(NSMenuItem.separator())
        }

        // Snippet title
        let labelItem = NSMenuItem(title: String(localized: "Snippet"), action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        var subMenuIndex = menu.numberOfItems - 1
        let firstIndex = firstIndexOfMenuItems()
        details
            .filter { $0.folder.isEnabled }
            .forEach { detail in
                let folderTitle = detail.folder.title
                let subMenuItem = makeSubmenuItem(folderTitle)
                menu.addItem(subMenuItem)
                subMenuIndex += 1

                var i = firstIndex
                detail.snippets
                    .filter { $0.isEnabled }
                    .forEach { snippet in
                        let subMenuItem = makeSnippetMenuItem(snippet, listNumber: i)
                        if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                            subMenu.addItem(subMenuItem)
                            i += 1
                        }
                    }
            }
    }

    func makeSnippetMenuItem(_ snippet: Snippet, listNumber: Int) -> NSMenuItem {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowIcon = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)

        let title = trimTitle(snippet.title)
        let titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectSnippetMenuItem(_:)), keyEquivalent: "")
        menuItem.target = NSApp.delegate
        menuItem.representedObject = snippet.id
        menuItem.toolTip = snippet.content
        menuItem.image = (isShowIcon) ? snippetIcon : nil

        return menuItem
    }
}

// MARK: - Status Item
private extension MenuManager {
    func changeStatusItem(_ type: StatusType) {
        if currentStatusType == type {
            if type == .none {
                guard statusItem != nil else { return }
            } else if statusItem != nil {
                return
            }
        }

        isUpdatingStatusItem = true
        defer {
            currentStatusType = type
            isUpdatingStatusItem = false
        }

        removeStatusItem()
        if type == .none { return }

        let image = makeStatusImage(for: type)
        image?.isTemplate = type == .black

        statusItem = NSStatusBar.system.statusItem(withLength: -1)
        statusItem?.button?.image = image
        (statusItem?.button?.cell as? NSButtonCell)?.highlightsBy = .contentsCellMask
        statusItem?.button?.toolTip = "\(Constants.Application.name)\(Bundle.main.appVersion ?? "")"
        statusItem?.menu = mainMenu
    }

    func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func makeStatusImage(for type: StatusType) -> NSImage? {
        switch type {
        case .black:
            if let symbolImage = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: Constants.Application.name
            ) {
                let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                let image = symbolImage.withSymbolConfiguration(configuration) ?? symbolImage
                image.size = NSSize(width: 18, height: 18)
                return image
            }
            return NSImage(named: "statusbar_menu_black")
        case .white:
            return NSImage(named: "statusbar_menu_black") ?? NSImage(named: "statusbar_menu_white")
        case .none:
            return nil
        }
    }
}

// MARK: - Settings
private extension MenuManager {
    func firstIndexOfMenuItems() -> NSInteger {
        return AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsTitleStartWithZero) ? 0 : 1
    }
}

// MARK: - NSMenuDelegate
extension MenuManager: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Find the item that owns this menu
        let allMenus = [mainMenu, historyMenu].compactMap { $0 }
        var parentItem: NSMenuItem?

        for topMenu in allMenus {
            if let item = topMenu.items.first(where: { $0.submenu === menu }) {
                parentItem = item
                break
            }
            // Check one level deeper for folders in mainMenu/historyMenu
            for item in topMenu.items {
                if let sub = item.submenu, let subItem = sub.items.first(where: { $0.submenu === menu }) {
                    parentItem = subItem
                    break
                }
            }
            if parentItem != nil { break }
        }

        guard let item = parentItem, let info = item.representedObject as? HistorySubmenuInfo else { return }
        
        // Only populate if empty
        guard menu.numberOfItems == 0 else { return }

        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let showsMenuItemIcons = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)
        let isShowImage = showsMenuItemIcons && AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = showsMenuItemIcons && AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        
        let historyDetails = pasteboardHistoryRepository.fetchHistoryDetails(
            ascending: ascending,
            includesThumbnailAsset: isShowImage || isShowColorCode,
            limit: info.limit,
            offset: info.offset
        )
        
        let firstIndex = firstIndexOfMenuItems()
        var listNumber = firstIndex
        for (i, detail) in historyDetails.enumerated() {
            let menuItem = makeHistoryMenuItem(detail, index: info.offset + i, listNumber: listNumber)
            menu.addItem(menuItem)
            listNumber = incrementListNumber(listNumber, max: info.limit, start: firstIndex)
        }
    }
}

private struct HistorySubmenuInfo {
    let offset: Int
    let limit: Int
}

#if DEBUG
extension MenuManager {
    func testBuildMenus() {
        snippetFolderDetails = snippetRepository.fetchFolderDetails()
        createMainMenu()
    }

    var testMainMenu: NSMenu? {
        mainMenu
    }

    var testHistoryMenu: NSMenu? {
        historyMenu
    }
}
#endif
