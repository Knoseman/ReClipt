//
//  CPYSnippetsEditorWindowController.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/05/18.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Cocoa

final class CPYSnippetsEditorWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController: CPYSnippetsEditorWindowController = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Edit Snippets")
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(white: 0.99, alpha: 1)
        return CPYSnippetsEditorWindowController(window: window)
    }()

    private var splitView: NSSplitView!
    private var folderTitleTextField: NSTextField!
    private var textView: NSTextView!
    private var outlineView: NSOutlineView!
    private var folderSettingView: NSView!

    private let snippetRepository = SnippetRepository()
    private var folders = [EditorSnippetFolder]()
    private var selectedFolder: EditorSnippetFolder? {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) else { return nil }
        return item as? EditorSnippetFolder ?? outlineView.parent(forItem: item) as? EditorSnippetFolder
    }

    // MARK: - Window Life Cycle
    override func windowDidLoad() {
        super.windowDidLoad()
        setupUI()
        folders = snippetRepository.fetchFolderDetails().map(EditorSnippetFolder.init)
        outlineView.reloadData()
        // Select first folder
        if let folder = folders.first {
            outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: folder)), byExtendingSelection: false)
            changeItemFocus()
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
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
        let scrollView = NSScrollView(frame: leftView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        outlineView = NSOutlineView()
        outlineView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: Constants.Common.draggedDataType)])
        scrollView.documentView = outlineView
        leftView.addSubview(scrollView)

        // Toolbar buttons
        let addSnippetButton = NSButton(frame: NSRect(x: 5, y: leftView.frame.height - 30, width: 60, height: 24))
        addSnippetButton.title = "+ Snippet"
        addSnippetButton.bezelStyle = .smallSquare
        addSnippetButton.target = self
        addSnippetButton.action = #selector(addSnippetButtonTapped(_:))
        addSnippetButton.autoresizingMask = [.minYMargin]
        leftView.addSubview(addSnippetButton)

        let addFolderButton = NSButton(frame: NSRect(x: 70, y: leftView.frame.height - 30, width: 60, height: 24))
        addFolderButton.title = "+ Folder"
        addFolderButton.bezelStyle = .smallSquare
        addFolderButton.target = self
        addFolderButton.action = #selector(addFolderButtonTapped(_:))
        addFolderButton.autoresizingMask = [.minYMargin]
        leftView.addSubview(addFolderButton)

        let deleteButton = NSButton(frame: NSRect(x: 135, y: leftView.frame.height - 30, width: 60, height: 24))
        deleteButton.title = "-"
        deleteButton.bezelStyle = .smallSquare
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonTapped(_:))
        deleteButton.autoresizingMask = [.minYMargin]
        leftView.addSubview(deleteButton)

        splitView.addSubview(leftView)

        // Right side - Editor
        let rightView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: contentView.frame.height))

        folderSettingView = NSView(frame: NSRect(x: 0, y: rightView.frame.height - 60, width: rightView.frame.width, height: 60))
        folderSettingView.autoresizingMask = [.width, .minYMargin]

        folderTitleTextField = NSTextField(frame: NSRect(x: 10, y: 20, width: folderSettingView.frame.width - 20, height: 24))
        folderTitleTextField.autoresizingMask = [.width]
        folderTitleTextField.target = self
        folderTitleTextField.action = #selector(folderTitleChanged(_:))
        folderSettingView.addSubview(folderTitleTextField)
        rightView.addSubview(folderSettingView)

        let textScrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: rightView.frame.width, height: rightView.frame.height - 60))
        textScrollView.autoresizingMask = [.width, .height]
        textScrollView.hasVerticalScroller = true
        textScrollView.borderType = .bezelBorder

        textView = NSTextView()
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isRichText = false
        textView.delegate = self
        textScrollView.documentView = textView
        rightView.addSubview(textScrollView)

        splitView.addSubview(rightView)
    }

    @objc private func folderTitleChanged(_ sender: NSTextField) {
        guard let folder = selectedFolder else { return }
        folder.title = sender.stringValue
        snippetRepository.updateFolderTitle(folder.id, title: sender.stringValue)
        outlineView.reloadItem(folder)
    }

    // MARK: - IBActions
    @IBAction private func addSnippetButtonTapped(_ sender: AnyObject) {
        guard let folder = selectedFolder, let snippet = snippetRepository.insertSnippet(to: folder.id) else {
            NSSound.beep()
            return
        }
        let editorSnippet = EditorSnippet(snippet: snippet)
        folder.snippets.append(editorSnippet)
        outlineView.reloadData()
        outlineView.expandItem(folder)
        outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: editorSnippet)), byExtendingSelection: false)
        changeItemFocus()
    }

    @IBAction private func addFolderButtonTapped(_ sender: AnyObject) {
        guard let folder = snippetRepository.insertFolder() else {
            NSSound.beep()
            return
        }
        let editorFolder = EditorSnippetFolder(folder: folder)
        folders.append(editorFolder)
        outlineView.reloadData()
        outlineView.selectRowIndexes(IndexSet(integer: outlineView.row(forItem: editorFolder)), byExtendingSelection: false)
        changeItemFocus()
    }

    @IBAction private func deleteButtonTapped(_ sender: AnyObject) {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) else {
            NSSound.beep()
            return
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "Delete Item")
        alert.informativeText = String(localized: "Are you sure want to delete this item?")
        alert.addButton(withTitle: String(localized: "Delete Item"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        if result != NSApplication.ModalResponse.alertFirstButtonReturn { return }

        if let folder = item as? EditorSnippetFolder {
            folders.removeAll(where: { $0.id == folder.id })
            snippetRepository.deleteFolder(folder.id)
            AppEnvironment.current.hotKeyService.unregisterSnippetHotKey(with: folder.id.uuidString)
        } else if let snippet = item as? EditorSnippet, let folder = outlineView.parent(forItem: item) as? EditorSnippetFolder {
            folder.snippets.removeAll(where: { $0.id == snippet.id })
            snippetRepository.deleteSnippet(snippet.id)
        }
        outlineView.reloadData()
        changeItemFocus()
    }

    @IBAction private func importSnippetButtonTapped(_ sender: AnyObject) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.allowedFileTypes = ["plist"]
        let returnCode = panel.runModal()

        if returnCode != NSApplication.ModalResponse.OK { return }

        let fileURLs = panel.urls
        guard let url = fileURLs.first else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        do {
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] else {
                NSSound.beep()
                return
            }
            let folders = plist.compactMap { dict -> (title: String, snippets: [(title: String, content: String)])? in
                guard let title = dict["title"] as? String,
                      let snippets = dict["snippets"] as? [[String: String]] else { return nil }
                let snippetData = snippets.compactMap { snippetDict -> (title: String, content: String)? in
                    guard let sTitle = snippetDict["title"], let sContent = snippetDict["content"] else { return nil }
                    return (title: sTitle, content: sContent)
                }
                return (title: title, snippets: snippetData)
            }
            guard let folderDetails = snippetRepository.insertFolders(folders) else {
                NSSound.beep()
                return
            }
            self.folders.append(contentsOf: folderDetails.map(EditorSnippetFolder.init))
            outlineView.reloadData()
        } catch {
            NSSound.beep()
        }
    }

    @IBAction private func exportSnippetButtonTapped(_ sender: AnyObject) {
        let plist: [[String: Any]] = folders.map { folder in
            [
                "title": folder.title,
                "snippets": folder.snippets.map { [
                    "title": $0.title,
                    "content": $0.content
                ] }
            ]
        }

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            let panel = NSSavePanel()
            panel.allowedFileTypes = ["plist"]
            panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
            panel.nameFieldStringValue = "snippets"
            let returnCode = panel.runModal()

            if returnCode != NSApplication.ModalResponse.OK { return }
            guard let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }
}

// MARK: - Item Selected
private extension CPYSnippetsEditorWindowController {
    func changeItemFocus() {
        // Reset TextView Undo/Redo history
        textView.undoManager?.removeAllActions()
        guard let item = outlineView.item(atRow: outlineView.selectedRow) else {
            folderSettingView.isHidden = true
            textView.isHidden = true
            folderTitleTextField.stringValue = ""
            return
        }
        if let folder = item as? EditorSnippetFolder {
            textView.string = ""
            folderTitleTextField.stringValue = folder.title
            folderSettingView.isHidden = false
            textView.isHidden = true
        } else if let snippet = item as? EditorSnippet {
            textView.string = snippet.content
            folderTitleTextField.stringValue = ""
            folderSettingView.isHidden = true
            textView.isHidden = false
        }
    }
}

// MARK: - NSSplitView Delegate
extension CPYSnippetsEditorWindowController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMinimumPosition + 150
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMaximumPosition / 2
    }
}

// MARK: - NSOutlineView DataSource
extension CPYSnippetsEditorWindowController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return folders.count
        } else if let folder = item as? EditorSnippetFolder {
            return folder.snippets.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? EditorSnippetFolder).map { !$0.snippets.isEmpty } ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? EditorSnippetFolder).map { $0.snippets[index] as Any } ?? folders[index] as Any
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        (item as? EditorSnippetFolder).map { $0.title } ?? (item as? EditorSnippet).map { $0.title } ?? ""
    }

    // MARK: - Drag and Drop
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
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
extension CPYSnippetsEditorWindowController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        guard let cell = cell as? NSTextFieldCell else { return }
        if let folder = item as? EditorSnippetFolder {
            cell.image = folder.isEnabled ? nil : nil // Add folder icon if desired
            cell.textColor = folder.isEnabled ? .labelColor : .secondaryLabelColor
        } else if let snippet = item as? EditorSnippet {
            cell.textColor = snippet.isEnabled ? .labelColor : .secondaryLabelColor
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        changeItemFocus()
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
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
}

// MARK: - NSTextView Delegate
extension CPYSnippetsEditorWindowController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let replacementString = replacementString else { return false }
        guard let snippet = outlineView.item(atRow: outlineView.selectedRow) as? EditorSnippet else { return false }

        let string = (textView.string as NSString).replacingCharacters(in: affectedCharRange, with: replacementString)
        snippet.content = string
        snippetRepository.updateSnippetContent(snippet.id, content: string)

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
