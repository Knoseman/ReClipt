//
//  SnippetsEditorWindowController.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa
import UniformTypeIdentifiers

enum SnippetsEditorControlIdentifier {
    static let searchField = NSUserInterfaceItemIdentifier("SnippetsEditor.searchField")
    static let addSnippetButton = NSUserInterfaceItemIdentifier("SnippetsEditor.addSnippetButton")
    static let addFolderButton = NSUserInterfaceItemIdentifier("SnippetsEditor.addFolderButton")
    static let deleteButton = NSUserInterfaceItemIdentifier("SnippetsEditor.deleteButton")
    static let importButton = NSUserInterfaceItemIdentifier("SnippetsEditor.importButton")
    static let exportButton = NSUserInterfaceItemIdentifier("SnippetsEditor.exportButton")
    static let folderTitleTextField = NSUserInterfaceItemIdentifier("SnippetsEditor.folderTitleTextField")
    static let folderEnabledCheckbox = NSUserInterfaceItemIdentifier("SnippetsEditor.folderEnabledCheckbox")
    static let snippetTitleTextField = NSUserInterfaceItemIdentifier("SnippetsEditor.snippetTitleTextField")
    static let snippetEnabledCheckbox = NSUserInterfaceItemIdentifier("SnippetsEditor.snippetEnabledCheckbox")
    static let textView = NSUserInterfaceItemIdentifier("SnippetsEditor.textView")
    static let outlineView = NSUserInterfaceItemIdentifier("SnippetsEditor.outlineView")
}

protocol SnippetsEditorDialogProviding {
    func confirmDeleteItem() -> Bool
    func importFileURL() -> URL?
    func exportFileURL(defaultFileName: String) -> URL?
}

struct AppKitSnippetsEditorDialogProvider: SnippetsEditorDialogProviding {
    func confirmDeleteItem() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Delete Item")
        alert.informativeText = String(localized: "Are you sure want to delete this item?")
        alert.addButton(withTitle: String(localized: "Delete Item"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }

    func importFileURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.allowedContentTypes = [.xml, .propertyList]
        return panel.runModal() == NSApplication.ModalResponse.OK ? panel.urls.first : nil
    }

    func exportFileURL(defaultFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.nameFieldStringValue = defaultFileName
        return panel.runModal() == NSApplication.ModalResponse.OK ? panel.url : nil
    }
}

final class SnippetsEditorWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController: SnippetsEditorWindowController = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Edit Snippets")
        window.titlebarAppearsTransparent = true
        return SnippetsEditorWindowController(window: window)
    }()

    private var splitView: NSSplitView!
    private var searchField: NSSearchField!
    private var folderTitleTextField: NSTextField!
    private var folderEnabledCheckbox: NSButton!
    private var snippetTitleTextField: NSTextField!
    private var snippetEnabledCheckbox: NSButton!
    private var textView: NSTextView!
    private var textScrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var folderSettingView: NSView!
    private var snippetSettingView: NSView!
    private var emptyStateLabel: NSTextField!
    private var updateSnippetTimer: Timer?

    private let snippetRepository: SnippetRepositoryProtocol
    private let dialogProvider: SnippetsEditorDialogProviding
    private var folders = [EditorSnippetFolder]()
    private var searchQuery = ""
    private var hasConfiguredWindow = false
    private var selectedFolder: EditorSnippetFolder? {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) else { return nil }
        return item as? EditorSnippetFolder ?? outlineView.parent(forItem: item) as? EditorSnippetFolder
    }
    private var isFiltering: Bool {
        !normalizedSearchQuery.isEmpty
    }
    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private var displayedFolders: [EditorSnippetFolder] {
        guard isFiltering else { return folders }
        return folders.filter { folder in
            folder.title.lowercased().contains(normalizedSearchQuery) ||
                folder.snippets.contains { snippetMatchesSearch($0) }
        }
    }

    // MARK: - Init

    init(
        window: NSWindow?,
        snippetRepository: SnippetRepositoryProtocol = SnippetRepository(),
        dialogProvider: SnippetsEditorDialogProviding = AppKitSnippetsEditorDialogProvider()
    ) {
        self.snippetRepository = snippetRepository
        self.dialogProvider = dialogProvider
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        self.snippetRepository = SnippetRepository()
        self.dialogProvider = AppKitSnippetsEditorDialogProvider()
        super.init(coder: coder)
    }

    // MARK: - Window Life Cycle
    override func windowDidLoad() {
        super.windowDidLoad()
        configureWindowIfNeeded()
    }

    override func showWindow(_ sender: Any?) {
        configureWindowIfNeeded()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func configureWindowIfNeeded() {
        guard !hasConfiguredWindow else { return }

        hasConfiguredWindow = true
        window?.setFrameAutosaveName("SnippetsEditorWindow")
        setupUI()
        folders = snippetRepository.fetchFolderDetails().map(EditorSnippetFolder.init)
        reloadSidebar()
        // Select first folder
        if let folder = folders.first {
            outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: folder)), byExtendingSelection: false)
            changeItemFocus()
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Split view
        splitView = NSSplitView(frame: contentView.bounds)
        splitView.autoresizingMask = [.width, .height]
        splitView.isVertical = true
        splitView.delegate = self
        contentView.addSubview(splitView)

        // Left side - Outline view
        let leftView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: contentView.frame.height))
        let leftToolbarHeight: CGFloat = 40
        let searchHeight: CGFloat = 34
        let toolbarView = NSView(frame: NSRect(x: 0, y: leftView.frame.height - leftToolbarHeight, width: leftView.frame.width, height: leftToolbarHeight))
        toolbarView.autoresizingMask = [.width, .minYMargin]

        searchField = NSSearchField(frame: NSRect(
            x: 8,
            y: leftView.frame.height - leftToolbarHeight - searchHeight + 5,
            width: leftView.frame.width - 16,
            height: 24
        ))
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.placeholderString = String(localized: "Search")
        searchField.identifier = SnippetsEditorControlIdentifier.searchField
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        leftView.addSubview(searchField)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: leftView.frame.width, height: leftView.frame.height - leftToolbarHeight - searchHeight))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        outlineView = NSOutlineView()
        outlineView.identifier = SnippetsEditorControlIdentifier.outlineView
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.dataCell = SnippetsEditorCell(textCell: "")
        outlineView.addTableColumn(nameColumn)
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: Constants.Common.draggedDataType)])
        scrollView.documentView = outlineView
        leftView.addSubview(scrollView)

        // Toolbar buttons
        let addSnippetButton = NSButton(frame: NSRect(x: 12, y: 8, width: 28, height: 24))
        addSnippetButton.title = ""
        addSnippetButton.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: String(localized: "Add Snippet"))
        addSnippetButton.identifier = SnippetsEditorControlIdentifier.addSnippetButton
        addSnippetButton.bezelStyle = .smallSquare
        addSnippetButton.toolTip = String(localized: "Add Snippet")
        addSnippetButton.target = self
        addSnippetButton.action = #selector(addSnippetButtonTapped(_:))
        toolbarView.addSubview(addSnippetButton)

        let addFolderButton = NSButton(frame: NSRect(x: 48, y: 8, width: 28, height: 24))
        addFolderButton.title = ""
        addFolderButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: String(localized: "Add Folder"))
        addFolderButton.identifier = SnippetsEditorControlIdentifier.addFolderButton
        addFolderButton.bezelStyle = .smallSquare
        addFolderButton.toolTip = String(localized: "Add Folder")
        addFolderButton.target = self
        addFolderButton.action = #selector(addFolderButtonTapped(_:))
        toolbarView.addSubview(addFolderButton)

        let deleteButton = NSButton(frame: NSRect(x: 84, y: 8, width: 28, height: 24))
        deleteButton.title = ""
        deleteButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: String(localized: "Delete"))
        deleteButton.identifier = SnippetsEditorControlIdentifier.deleteButton
        deleteButton.bezelStyle = .smallSquare
        deleteButton.toolTip = String(localized: "Delete")
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonTapped(_:))
        toolbarView.addSubview(deleteButton)

        let importButton = NSButton(frame: NSRect(x: 124, y: 8, width: 28, height: 24))
        importButton.title = ""
        importButton.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: String(localized: "Import Snippets"))
        importButton.identifier = SnippetsEditorControlIdentifier.importButton
        importButton.bezelStyle = .smallSquare
        importButton.toolTip = String(localized: "Import Snippets")
        importButton.target = self
        importButton.action = #selector(importSnippetButtonTapped(_:))
        toolbarView.addSubview(importButton)

        let exportButton = NSButton(frame: NSRect(x: 160, y: 8, width: 28, height: 24))
        exportButton.title = ""
        exportButton.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: String(localized: "Export Snippets"))
        exportButton.identifier = SnippetsEditorControlIdentifier.exportButton
        exportButton.bezelStyle = .smallSquare
        exportButton.toolTip = String(localized: "Export Snippets")
        exportButton.target = self
        exportButton.action = #selector(exportSnippetButtonTapped(_:))
        toolbarView.addSubview(exportButton)

        leftView.addSubview(toolbarView)

        splitView.addSubview(leftView)

        // Right side - Editor
        let rightView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: contentView.frame.height))

        let settingsHeight: CGFloat = 96
        folderSettingView = NSView(frame: NSRect(x: 0, y: rightView.frame.height - settingsHeight, width: rightView.frame.width, height: settingsHeight))
        folderSettingView.autoresizingMask = [.width, .minYMargin]

        let folderTitleLabel = NSTextField(labelWithString: String(localized: "Folder"))
        folderTitleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        folderTitleLabel.textColor = .secondaryLabelColor
        folderTitleLabel.frame = NSRect(x: 14, y: 66, width: 120, height: 18)
        folderSettingView.addSubview(folderTitleLabel)

        folderTitleTextField = NSTextField(frame: NSRect(x: 14, y: 36, width: folderSettingView.frame.width - 28, height: 24))
        folderTitleTextField.identifier = SnippetsEditorControlIdentifier.folderTitleTextField
        folderTitleTextField.autoresizingMask = [.width]
        folderTitleTextField.target = self
        folderTitleTextField.action = #selector(folderTitleChanged(_:))
        folderSettingView.addSubview(folderTitleTextField)

        folderEnabledCheckbox = NSButton(checkboxWithTitle: String(localized: "Enabled"), target: self, action: #selector(folderEnabledChanged(_:)))
        folderEnabledCheckbox.identifier = SnippetsEditorControlIdentifier.folderEnabledCheckbox
        folderEnabledCheckbox.frame = NSRect(x: 14, y: 8, width: 120, height: 22)
        folderSettingView.addSubview(folderEnabledCheckbox)
        rightView.addSubview(folderSettingView)

        snippetSettingView = NSView(frame: NSRect(x: 0, y: rightView.frame.height - settingsHeight, width: rightView.frame.width, height: settingsHeight))
        snippetSettingView.autoresizingMask = [.width, .minYMargin]

        let snippetTitleLabel = NSTextField(labelWithString: String(localized: "Snippet"))
        snippetTitleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        snippetTitleLabel.textColor = .secondaryLabelColor
        snippetTitleLabel.frame = NSRect(x: 14, y: 66, width: 120, height: 18)
        snippetSettingView.addSubview(snippetTitleLabel)

        snippetTitleTextField = NSTextField(frame: NSRect(x: 14, y: 36, width: snippetSettingView.frame.width - 28, height: 24))
        snippetTitleTextField.identifier = SnippetsEditorControlIdentifier.snippetTitleTextField
        snippetTitleTextField.autoresizingMask = [.width]
        snippetTitleTextField.target = self
        snippetTitleTextField.action = #selector(snippetTitleChanged(_:))
        snippetSettingView.addSubview(snippetTitleTextField)

        snippetEnabledCheckbox = NSButton(checkboxWithTitle: String(localized: "Enabled"), target: self, action: #selector(snippetEnabledChanged(_:)))
        snippetEnabledCheckbox.identifier = SnippetsEditorControlIdentifier.snippetEnabledCheckbox
        snippetEnabledCheckbox.frame = NSRect(x: 14, y: 8, width: 120, height: 22)
        snippetSettingView.addSubview(snippetEnabledCheckbox)
        rightView.addSubview(snippetSettingView)

        textScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: rightView.frame.width, height: rightView.frame.height - settingsHeight))
        textScrollView.autoresizingMask = [.width, .height]
        textScrollView.hasVerticalScroller = true
        textScrollView.borderType = .bezelBorder

        textView = NSTextView()
        textView.identifier = SnippetsEditorControlIdentifier.textView
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isRichText = false
        textView.delegate = self
        textScrollView.documentView = textView
        rightView.addSubview(textScrollView)

        emptyStateLabel = NSTextField(labelWithString: "")
        emptyStateLabel.alignment = .center
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.font = NSFont.systemFont(ofSize: 14)
        emptyStateLabel.frame = NSRect(x: 24, y: (rightView.frame.height - 24) / 2, width: rightView.frame.width - 48, height: 24)
        emptyStateLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        rightView.addSubview(emptyStateLabel)

        splitView.addSubview(rightView)
    }

    @objc private func folderTitleChanged(_ sender: NSTextField) {
        guard let folder = selectedFolder else { return }
        folder.title = sender.stringValue
        snippetRepository.updateFolderTitle(folder.id, title: sender.stringValue)
        reloadSidebar(select: folder)
    }

    @objc private func folderEnabledChanged(_ sender: NSButton) {
        guard let folder = selectedFolder else { return }
        folder.isEnabled = sender.state == .on
        snippetRepository.updateFolderIsEnabled(folder.id, isEnabled: folder.isEnabled)
        outlineView.reloadItem(folder, reloadChildren: true)
    }

    @objc private func snippetTitleChanged(_ sender: NSTextField) {
        guard let snippet = outlineView.item(atRow: outlineView.selectedRow) as? EditorSnippet else { return }
        snippet.title = sender.stringValue
        snippetRepository.updateSnippetTitle(snippet.id, title: sender.stringValue)
        reloadSidebar(select: snippet)
    }

    @objc private func snippetEnabledChanged(_ sender: NSButton) {
        guard let snippet = outlineView.item(atRow: outlineView.selectedRow) as? EditorSnippet else { return }
        snippet.isEnabled = sender.state == .on
        snippetRepository.updateSnippetIsEnabled(snippet.id, isEnabled: snippet.isEnabled)
        outlineView.reloadItem(snippet)
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        searchQuery = sender.stringValue
        reloadSidebar()
    }

    // MARK: - IBActions
    @IBAction private func addSnippetButtonTapped(_ sender: AnyObject) {
        guard let folder = selectedFolder, let snippet = snippetRepository.insertSnippet(to: folder.id) else {
            NSSound.beep()
            return
        }
        clearSearchIfNeeded()
        let editorSnippet = EditorSnippet(snippet: snippet)
        folder.snippets.append(editorSnippet)
        reloadSidebar(select: editorSnippet)
        outlineView.expandItem(folder)
    }

    @IBAction private func addFolderButtonTapped(_ sender: AnyObject) {
        guard let folder = snippetRepository.insertFolder() else {
            NSSound.beep()
            return
        }
        clearSearchIfNeeded()
        let editorFolder = EditorSnippetFolder(folder: folder)
        folders.append(editorFolder)
        reloadSidebar(select: editorFolder)
    }

    @IBAction private func deleteButtonTapped(_ sender: AnyObject) {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) else {
            NSSound.beep()
            return
        }

        guard dialogProvider.confirmDeleteItem() else { return }

        if let folder = item as? EditorSnippetFolder {
            folders.removeAll(where: { $0.id == folder.id })
            snippetRepository.deleteFolder(folder.id)
            AppEnvironment.current.hotKeyService.unregisterSnippetHotKey(with: folder.id.uuidString)
        } else if let snippet = item as? EditorSnippet, let folder = outlineView.parent(forItem: item) as? EditorSnippetFolder {
            folder.snippets.removeAll(where: { $0.id == snippet.id })
            snippetRepository.deleteSnippet(snippet.id)
        }
        reloadSidebar()
    }

    @IBAction private func importSnippetButtonTapped(_ sender: AnyObject) {
        guard let url = dialogProvider.importFileURL() else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        do {
            let transferFolders = try SnippetTransfer.importFolders(from: data, fileExtension: url.pathExtension)
            guard let folderDetails = snippetRepository.insertTransferFolders(transferFolders) else {
                NSSound.beep()
                return
            }
            clearSearchIfNeeded()
            let importedFolders = folderDetails.map(EditorSnippetFolder.init)
            self.folders.append(contentsOf: importedFolders)
            reloadSidebar(select: importedFolders.first)
        } catch {
            NSSound.beep()
        }
    }

    @IBAction private func exportSnippetButtonTapped(_ sender: AnyObject) {
        do {
            let transferFolders = folders.map(SnippetTransferFolder.init)
            let data = try SnippetTransfer.exportXML(folders: transferFolders)
            guard let url = dialogProvider.exportFileURL(defaultFileName: "snippets.xml") else { return }
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }
}

// MARK: - Item Selected
private extension SnippetsEditorWindowController {
    func reloadSidebar(select item: Any? = nil) {
        outlineView.reloadData()
        if isFiltering {
            displayedFolders.forEach { outlineView.expandItem($0) }
        }

        if let item {
            if let snippet = item as? EditorSnippet,
               let folder = folders.first(where: { $0.id == snippet.folderID }) {
                outlineView.expandItem(folder)
            }
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                changeItemFocus()
                return
            }
        }

        if outlineView.selectedRow >= outlineView.numberOfRows {
            outlineView.deselectAll(nil)
        }
        changeItemFocus()
    }

    func clearSearchIfNeeded() {
        guard isFiltering else { return }
        searchQuery = ""
        searchField.stringValue = ""
    }

    func snippets(for folder: EditorSnippetFolder) -> [EditorSnippet] {
        guard isFiltering else { return folder.snippets }
        if folder.title.lowercased().contains(normalizedSearchQuery) {
            return folder.snippets
        }
        return folder.snippets.filter(snippetMatchesSearch)
    }

    func snippetMatchesSearch(_ snippet: EditorSnippet) -> Bool {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return true }
        return snippet.title.lowercased().contains(query) || snippet.content.lowercased().contains(query)
    }

    func changeItemFocus() {
        // Reset TextView Undo/Redo history
        textView.undoManager?.removeAllActions()
        folderSettingView.isHidden = true
        snippetSettingView.isHidden = true
        textScrollView.isHidden = true
        emptyStateLabel.isHidden = true

        guard let item = outlineView.item(atRow: outlineView.selectedRow) else {
            folderTitleTextField.stringValue = ""
            snippetTitleTextField.stringValue = ""
            textView.string = ""
            emptyStateLabel.stringValue = isFiltering
                ? String(localized: "No snippets match your search.")
                : String(localized: "Select a folder or snippet.")
            emptyStateLabel.isHidden = false
            return
        }
        if let folder = item as? EditorSnippetFolder {
            textView.string = ""
            folderTitleTextField.stringValue = folder.title
            folderEnabledCheckbox.state = folder.isEnabled ? .on : .off
            folderSettingView.isHidden = false
            emptyStateLabel.stringValue = folder.snippets.isEmpty
                ? String(localized: "This folder is empty.")
                : String(localized: "Select a snippet to edit its content.")
            emptyStateLabel.isHidden = false
        } else if let snippet = item as? EditorSnippet {
            textView.string = snippet.content
            snippetTitleTextField.stringValue = snippet.title
            snippetEnabledCheckbox.state = snippet.isEnabled ? .on : .off
            folderTitleTextField.stringValue = ""
            snippetSettingView.isHidden = false
            textScrollView.isHidden = false
        }
    }
}

// MARK: - NSSplitView Delegate
extension SnippetsEditorWindowController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMinimumPosition + 150
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMaximumPosition / 2
    }
}

// MARK: - NSOutlineView DataSource
extension SnippetsEditorWindowController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return displayedFolders.count
        } else if let folder = item as? EditorSnippetFolder {
            return snippets(for: folder).count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? EditorSnippetFolder).map { !snippets(for: $0).isEmpty } ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? EditorSnippetFolder).map { snippets(for: $0)[index] as Any } ?? displayedFolders[index] as Any
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        (item as? EditorSnippetFolder).map { $0.title } ?? (item as? EditorSnippet).map { $0.title } ?? ""
    }

    // MARK: - Drag and Drop
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard !isFiltering else { return nil }
        let pasteboardItem = NSPasteboardItem()
        if let folder = item as? EditorSnippetFolder, let index = folders.firstIndex(where: { $0.id == folder.id }) {
            let draggedData = DraggedData(type: .folder, folderID: folder.id, snippetID: nil, index: index)
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: draggedData, requiringSecureCoding: true) else { return nil }
            pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(rawValue: Constants.Common.draggedDataType))
        } else if let snippet = item as? EditorSnippet, let folder = outlineView.parent(forItem: snippet) as? EditorSnippetFolder {
            guard let index = folder.snippets.firstIndex(where: { $0.id == snippet.id }) else { return nil }
            let draggedData = DraggedData(type: .snippet, folderID: folder.id, snippetID: snippet.id, index: index)
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: draggedData, requiringSecureCoding: true) else { return nil }
            pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(rawValue: Constants.Common.draggedDataType))
        } else {
            return nil
        }
        return pasteboardItem
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard !isFiltering else { return NSDragOperation() }
        let pasteboard = info.draggingPasteboard
        guard let data = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: Constants.Common.draggedDataType)) else { return NSDragOperation() }
        guard let draggedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [DraggedData.self, NSUUID.self], from: data) as? DraggedData else { return NSDragOperation() }

        switch draggedData.type {
        case .folder where item == nil:
            return .move
        case .snippet where item is EditorSnippetFolder:
            return .move
        default:
            return NSDragOperation()
        }
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard !isFiltering else { return false }
        let pasteboard = info.draggingPasteboard
        guard let data = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: Constants.Common.draggedDataType)) else { return false }
        guard let draggedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [DraggedData.self, NSUUID.self], from: data) as? DraggedData else { return false }

        switch draggedData.type {
        case .folder where index != draggedData.index && index >= 0:
            guard let folder = folders.first(where: { $0.id == draggedData.folderID }) else { return false }
            folders.insert(folder, at: index)
            let removedIndex = (index < draggedData.index) ? draggedData.index + 1 : draggedData.index
            folders.remove(at: removedIndex)
            snippetRepository.updateFolderIndexes(folders.map(\.id))
            outlineView.reloadData()
            outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: folder)), byExtendingSelection: false)
            changeItemFocus()
            return true
        case .snippet:
            guard let fromFolder = folders.first(where: { $0.id == draggedData.folderID }) else { return false }
            guard let toFolder = item as? EditorSnippetFolder else { return false }
            guard let snippet = fromFolder.snippets.first(where: { $0.id == draggedData.snippetID }) else { return false }

            if draggedData.folderID == toFolder.id {
                guard index >= 0, index != draggedData.index else { return false }
                // Move to same folder
                fromFolder.snippets.insert(snippet, at: index)
                let removedIndex = (index < draggedData.index) ? draggedData.index + 1 : draggedData.index
                fromFolder.snippets.remove(at: removedIndex)
                snippetRepository.updateSnippetIndexes(fromFolder.snippets.map(\.id))
                outlineView.reloadData()
                outlineView.selectRowIndexes(NSIndexSet(index: outlineView.row(forItem: snippet)) as IndexSet, byExtendingSelection: false)
                changeItemFocus()
                return true
            } else {
                // Move to other folder
                let index = max(0, index)
                toFolder.snippets.insert(snippet, at: index)
                fromFolder.snippets.removeAll(where: { $0.id == snippet.id })
                snippetRepository.moveSnippet(snippet.id, to: toFolder.id, snippetIDs: toFolder.snippets.map(\.id))
                outlineView.reloadData()
                outlineView.expandItem(toFolder)
                outlineView.selectRowIndexes(NSIndexSet(index: outlineView.row(forItem: snippet)) as IndexSet, byExtendingSelection: false)
                changeItemFocus()
                return true
            }
        default:
            return false
        }
    }
}

// MARK: - NSOutlineView Delegate
extension SnippetsEditorWindowController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        guard let cell = cell as? NSTextFieldCell else { return }
        if let folder = item as? EditorSnippetFolder {
            if let snippetCell = cell as? SnippetsEditorCell {
                snippetCell.iconType = .folder
                snippetCell.isItemEnabled = folder.isEnabled
            }
            cell.textColor = folder.isEnabled ? .labelColor : .secondaryLabelColor
        } else if let snippet = item as? EditorSnippet {
            if let snippetCell = cell as? SnippetsEditorCell {
                snippetCell.iconType = .none
                snippetCell.isItemEnabled = snippet.isEnabled
            }
            cell.textColor = snippet.isEnabled ? .labelColor : .secondaryLabelColor
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        changeItemFocus()
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if control === searchField {
            return true
        }
        let text = fieldEditor.string
        guard !text.isEmpty else { return false }
        guard let outlineView = control as? NSOutlineView else { return false }
        guard let item = outlineView.item(atRow: outlineView.selectedRow) else { return false }
        if let folder = item as? EditorSnippetFolder {
            folder.title = text
            snippetRepository.updateFolderTitle(folder.id, title: text)
        } else if let snippet = item as? EditorSnippet {
            snippet.title = text
            snippetRepository.updateSnippetTitle(snippet.id, title: text)
        }
        changeItemFocus()
        return true
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        searchQuery = field.stringValue
        reloadSidebar()
    }
}

// MARK: - NSTextView Delegate
extension SnippetsEditorWindowController: NSTextViewDelegate, NSSearchFieldDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let replacementString = replacementString else { return false }
        guard let snippet = outlineView.item(atRow: outlineView.selectedRow) as? EditorSnippet else { return false }

        let string = (textView.string as NSString).replacingCharacters(in: affectedCharRange, with: replacementString)
        snippet.content = string

        updateSnippetTimer?.invalidate()
        updateSnippetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.snippetRepository.updateSnippetContent(snippet.id, content: string)
        }

        return true
    }
}

// MARK: - Objects

private final class EditorSnippetFolder: NSObject {
    let id: SnippetFolder.ID
    var title: String
    var index: Int
    var isEnabled: Bool
    var snippets: [EditorSnippet]

    init(folderDetail: SnippetFolderDetail) {
        self.id = folderDetail.folder.id
        self.title = folderDetail.folder.title
        self.index = folderDetail.folder.index
        self.isEnabled = folderDetail.folder.isEnabled
        self.snippets = folderDetail.snippets.map(EditorSnippet.init)
        super.init()
    }

    init(folder: SnippetFolder) {
        self.id = folder.id
        self.title = folder.title
        self.index = folder.index
        self.isEnabled = folder.isEnabled
        self.snippets = []
        super.init()
    }
}

private final class EditorSnippet: NSObject {
    let id: Snippet.ID
    var folderID: SnippetFolder.ID
    var title: String
    var content: String
    var index: Int
    var isEnabled: Bool

    init(snippet: Snippet) {
        self.id = snippet.id
        self.folderID = snippet.folderID
        self.title = snippet.title
        self.content = snippet.content
        self.index = snippet.index
        self.isEnabled = snippet.isEnabled
        super.init()
    }
}

private extension SnippetTransferFolder {
    init(editorFolder: EditorSnippetFolder) {
        self.init(
            id: editorFolder.id,
            title: editorFolder.title,
            index: editorFolder.index,
            isEnabled: editorFolder.isEnabled,
            snippets: editorFolder.snippets.map(SnippetTransferSnippet.init)
        )
    }
}

private extension SnippetTransferSnippet {
    init(editorSnippet: EditorSnippet) {
        self.init(
            id: editorSnippet.id,
            title: editorSnippet.title,
            content: editorSnippet.content,
            index: editorSnippet.index,
            isEnabled: editorSnippet.isEnabled
        )
    }
}
