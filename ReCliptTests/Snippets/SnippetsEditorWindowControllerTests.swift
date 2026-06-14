//
//  SnippetsEditorWindowControllerTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/14.
//
//  Copyright © 2026 ReClipt Project.
//

import AppKit
import Foundation
import Testing
@testable import ReClipt

@MainActor
@Suite(.serialized)
struct SnippetsEditorWindowControllerTests {
    @Test
    func initialLoadSelectsFirstFolder() throws {
        let repository = FakeSnippetRepository(folderDetails: [
            folderDetail(title: "Common", snippets: [snippet(title: "Email", content: "test@example.com")])
        ])
        let controller = makeController(repository: repository)
        let view = try #require(controller.window?.contentView)

        let outlineView = try editorOutlineView(in: view)
        let folderTitleField = try editorTextField(in: view, identifier: SnippetsEditorControlIdentifier.folderTitleTextField)
        let folderEnabledCheckbox = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.folderEnabledCheckbox)

        #expect(outlineView.numberOfRows == 1)
        #expect(outlineObjectValue(controller, outlineView, row: 0) == "Common")
        #expect(folderTitleField.stringValue == "Common")
        #expect(folderEnabledCheckbox.state == NSControl.StateValue.on)
    }

    @Test
    func addFolderCreatesSelectsAndDisplaysFolder() throws {
        let repository = FakeSnippetRepository(folderDetails: [
            folderDetail(title: "Common")
        ])
        let controller = makeController(repository: repository)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let addFolderButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.addFolderButton)
        let folderTitleField = try editorTextField(in: view, identifier: SnippetsEditorControlIdentifier.folderTitleTextField)

        addFolderButton.sendAction(addFolderButton.action, to: addFolderButton.target)

        #expect(repository.insertFolderCallCount == 1)
        #expect(outlineView.numberOfRows == 2)
        #expect(outlineObjectValue(controller, outlineView, row: 1) == "New Folder")
        #expect(folderTitleField.stringValue == "New Folder")
        #expect(outlineView.selectedRow == 1)
    }

    @Test
    func addSnippetCreatesSelectsAndDisplaysSnippet() throws {
        let initialFolder = SnippetFolder(id: UUID(), title: "Common", index: 0, isEnabled: true)
        let repository = FakeSnippetRepository(folderDetails: [
            SnippetFolderDetail(folder: initialFolder, snippets: [])
        ])
        let controller = makeController(repository: repository)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let addSnippetButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.addSnippetButton)
        let snippetTitleField = try editorTextField(in: view, identifier: SnippetsEditorControlIdentifier.snippetTitleTextField)

        addSnippetButton.sendAction(addSnippetButton.action, to: addSnippetButton.target)

        #expect(repository.insertSnippetFolderIDs == [initialFolder.id])
        #expect(outlineView.numberOfRows == 2)
        #expect(outlineObjectValue(controller, outlineView, row: 1) == "New Snippet")
        #expect(snippetTitleField.stringValue == "New Snippet")
        #expect(outlineView.selectedRow == 1)
    }

    @Test
    func searchUsesRepositorySearchResults() throws {
        let repository = FakeSnippetRepository(folderDetails: [
            folderDetail(title: "Common", snippets: [snippet(title: "Email", content: "test@example.com")]),
            folderDetail(title: "Work", snippets: [snippet(title: "Deploy", content: "not loaded by local filtering")])
        ])
        repository.searchResults["need"] = [
            folderDetail(title: "Work", snippets: [snippet(title: "Deploy", content: "repository result")])
        ]
        let controller = makeController(repository: repository)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let searchField = try editorSearchField(in: view)

        searchField.stringValue = "need"
        searchField.sendAction(searchField.action, to: searchField.target)

        #expect(repository.searchQueries == ["need"])
        #expect(controller.outlineView(outlineView, numberOfChildrenOfItem: nil as Any?) == 1)
        #expect(outlineView.numberOfRows == 2)
        #expect(outlineObjectValue(controller, outlineView, row: 0) == "Work")
        #expect(outlineObjectValue(controller, outlineView, row: 1) == "Deploy")
    }

    @Test
    func titleAndEnabledControlsPersistSelectionChanges() throws {
        let folderID = UUID()
        let snippetID = UUID()
        let repository = FakeSnippetRepository(folderDetails: [
            SnippetFolderDetail(
                folder: SnippetFolder(id: folderID, title: "Common", index: 0, isEnabled: true),
                snippets: [
                    Snippet(
                        id: snippetID,
                        folderID: folderID,
                        title: "Email",
                        content: "test@example.com",
                        index: 0,
                        isEnabled: true
                    )
                ]
            )
        ])
        let controller = makeController(repository: repository)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let folderTitleField = try editorTextField(in: view, identifier: SnippetsEditorControlIdentifier.folderTitleTextField)
        let folderEnabledCheckbox = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.folderEnabledCheckbox)
        let snippetTitleField = try editorTextField(in: view, identifier: SnippetsEditorControlIdentifier.snippetTitleTextField)
        let snippetEnabledCheckbox = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.snippetEnabledCheckbox)

        folderTitleField.stringValue = "Personal"
        folderTitleField.sendAction(folderTitleField.action, to: folderTitleField.target)
        folderEnabledCheckbox.state = .off
        folderEnabledCheckbox.sendAction(folderEnabledCheckbox.action, to: folderEnabledCheckbox.target)

        let folderItem = try #require(outlineView.item(atRow: 0))
        outlineView.expandItem(folderItem)
        outlineView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)

        snippetTitleField.stringValue = "Primary Email"
        snippetTitleField.sendAction(snippetTitleField.action, to: snippetTitleField.target)
        snippetEnabledCheckbox.state = .off
        snippetEnabledCheckbox.sendAction(snippetEnabledCheckbox.action, to: snippetEnabledCheckbox.target)

        #expect(repository.updatedFolderTitles[folderID] == "Personal")
        #expect(repository.updatedFolderEnabledStates[folderID] == false)
        #expect(repository.updatedSnippetTitles[snippetID] == "Primary Email")
        #expect(repository.updatedSnippetEnabledStates[snippetID] == false)
    }

    @Test
    func snippetBodyEditsAreDebouncedAndPersisted() throws {
        let folderID = UUID()
        let snippetID = UUID()
        let repository = FakeSnippetRepository(folderDetails: [
            SnippetFolderDetail(
                folder: SnippetFolder(id: folderID, title: "Common", index: 0, isEnabled: true),
                snippets: [
                    Snippet(
                        id: snippetID,
                        folderID: folderID,
                        title: "Email",
                        content: "old@example.com",
                        index: 0,
                        isEnabled: true
                    )
                ]
            )
        ])
        let controller = makeController(repository: repository)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let textView = try editorTextView(in: view)

        let folderItem = try #require(outlineView.item(atRow: 0))
        outlineView.expandItem(folderItem)
        outlineView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        textView.string = "old@example.com"

        let shouldChange = controller.textView(
            textView,
            shouldChangeTextIn: NSRange(location: 0, length: textView.string.utf16.count),
            replacementString: "new@example.com"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))

        #expect(shouldChange)
        #expect(repository.updatedSnippetContents[snippetID] == "new@example.com")
    }

    @Test
    func deleteFolderConfirmationDeletesSelectedFolder() throws {
        let folderID = UUID()
        let repository = FakeSnippetRepository(folderDetails: [
            SnippetFolderDetail(
                folder: SnippetFolder(id: folderID, title: "Common", index: 0, isEnabled: true),
                snippets: []
            )
        ])
        let dialogProvider = FakeSnippetsEditorDialogProvider(confirmDeleteResult: true)
        let controller = makeController(repository: repository, dialogProvider: dialogProvider)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let deleteButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.deleteButton)

        deleteButton.sendAction(deleteButton.action, to: deleteButton.target)

        #expect(dialogProvider.confirmDeleteCallCount == 1)
        #expect(repository.deletedFolderIDs == [folderID])
        #expect(outlineView.numberOfRows == 0)
    }

    @Test
    func deleteSnippetConfirmationDeletesSelectedSnippet() throws {
        let folderID = UUID()
        let snippetID = UUID()
        let repository = FakeSnippetRepository(folderDetails: [
            SnippetFolderDetail(
                folder: SnippetFolder(id: folderID, title: "Common", index: 0, isEnabled: true),
                snippets: [
                    Snippet(
                        id: snippetID,
                        folderID: folderID,
                        title: "Email",
                        content: "test@example.com",
                        index: 0,
                        isEnabled: true
                    )
                ]
            )
        ])
        let dialogProvider = FakeSnippetsEditorDialogProvider(confirmDeleteResult: true)
        let controller = makeController(repository: repository, dialogProvider: dialogProvider)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let deleteButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.deleteButton)

        let folderItem = try #require(outlineView.item(atRow: 0))
        outlineView.expandItem(folderItem)
        outlineView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        deleteButton.sendAction(deleteButton.action, to: deleteButton.target)

        #expect(dialogProvider.confirmDeleteCallCount == 1)
        #expect(repository.deletedSnippetIDs == [snippetID])
        #expect(outlineView.numberOfRows == 1)
    }

    @Test
    func deleteCancellationDoesNotDeleteSelectedFolder() throws {
        let folderID = UUID()
        let repository = FakeSnippetRepository(folderDetails: [
            SnippetFolderDetail(
                folder: SnippetFolder(id: folderID, title: "Common", index: 0, isEnabled: true),
                snippets: []
            )
        ])
        let dialogProvider = FakeSnippetsEditorDialogProvider(confirmDeleteResult: false)
        let controller = makeController(repository: repository, dialogProvider: dialogProvider)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let deleteButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.deleteButton)

        deleteButton.sendAction(deleteButton.action, to: deleteButton.target)

        #expect(dialogProvider.confirmDeleteCallCount == 1)
        #expect(repository.deletedFolderIDs.isEmpty)
        #expect(outlineView.numberOfRows == 1)
    }

    @Test
    func importSelectedFileAddsImportedFolder() throws {
        let importURL = try temporaryFileURL(fileName: "snippets.xml")
        defer { try? FileManager.default.removeItem(at: importURL.deletingLastPathComponent()) }
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <folders>
            <folder>
                <title>Imported</title>
                <snippets>
                    <snippet>
                        <title>Greeting</title>
                        <content>Hello</content>
                    </snippet>
                </snippets>
            </folder>
        </folders>
        """
        try Data(xml.utf8).write(to: importURL)

        let repository = FakeSnippetRepository(folderDetails: [])
        let dialogProvider = FakeSnippetsEditorDialogProvider(importURL: importURL)
        let controller = makeController(repository: repository, dialogProvider: dialogProvider)
        let view = try #require(controller.window?.contentView)
        let outlineView = try editorOutlineView(in: view)
        let importButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.importButton)

        importButton.sendAction(importButton.action, to: importButton.target)

        #expect(dialogProvider.importFileCallCount == 1)
        #expect(repository.folderDetails.count == 1)
        #expect(repository.folderDetails[0].folder.title == "Imported")
        #expect(repository.folderDetails[0].snippets.first?.title == "Greeting")
        #expect(outlineView.numberOfRows == 1)
        #expect(outlineObjectValue(controller, outlineView, row: 0) == "Imported")
    }

    @Test
    func exportSelectedFileWritesCurrentFolders() throws {
        let exportURL = try temporaryFileURL(fileName: "exported.xml")
        defer { try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent()) }
        let repository = FakeSnippetRepository(folderDetails: [
            folderDetail(title: "Common", snippets: [snippet(title: "Email", content: "test@example.com")]),
            folderDetail(title: "Filtered Out", snippets: [snippet(title: "Hidden", content: "export me too")])
        ])
        repository.searchResults["email"] = [
            folderDetail(title: "Common", snippets: [snippet(title: "Email", content: "test@example.com")])
        ]
        let dialogProvider = FakeSnippetsEditorDialogProvider(exportURL: exportURL)
        let controller = makeController(repository: repository, dialogProvider: dialogProvider)
        let view = try #require(controller.window?.contentView)
        let searchField = try editorSearchField(in: view)
        let exportButton = try editorButton(in: view, identifier: SnippetsEditorControlIdentifier.exportButton)

        searchField.stringValue = "email"
        searchField.sendAction(searchField.action, to: searchField.target)
        exportButton.sendAction(exportButton.action, to: exportButton.target)

        let exportedXML = try #require(String(data: Data(contentsOf: exportURL), encoding: .utf8))
        #expect(dialogProvider.exportFileCallCount == 1)
        #expect(dialogProvider.defaultExportFileNames == ["snippets.xml"])
        #expect(exportedXML.contains("format=\"reclipt-snippets\""))
        #expect(exportedXML.contains("<title>Common</title>"))
        #expect(exportedXML.contains("<title>Email</title>"))
        #expect(exportedXML.contains("test@example.com"))
        #expect(exportedXML.contains("<title>Filtered Out</title>"))
        #expect(exportedXML.contains("export me too"))
    }
}

private extension SnippetsEditorWindowControllerTests {
    func makeController(
        repository: FakeSnippetRepository,
        dialogProvider: FakeSnippetsEditorDialogProvider = FakeSnippetsEditorDialogProvider()
    ) -> SnippetsEditorWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Snippets"
        let controller = SnippetsEditorWindowController(
            window: window,
            snippetRepository: repository,
            dialogProvider: dialogProvider
        )
        controller.configureWindowIfNeeded()
        return controller
    }

    func temporaryFileURL(fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReCliptTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    func folderDetail(
        title: String,
        snippets: [Snippet] = [],
        isEnabled: Bool = true
    ) -> SnippetFolderDetail {
        let folder = SnippetFolder(id: UUID(), title: title, index: 0, isEnabled: isEnabled)
        return SnippetFolderDetail(folder: folder, snippets: snippets.map { snippet in
            Snippet(
                id: snippet.id,
                folderID: folder.id,
                title: snippet.title,
                content: snippet.content,
                index: snippet.index,
                isEnabled: snippet.isEnabled
            )
        })
    }

    func snippet(
        title: String,
        content: String,
        isEnabled: Bool = true
    ) -> Snippet {
        Snippet(
            id: UUID(),
            folderID: UUID(),
            title: title,
            content: content,
            index: 0,
            isEnabled: isEnabled
        )
    }

    func outlineObjectValue(
        _ controller: SnippetsEditorWindowController,
        _ outlineView: NSOutlineView,
        row: Int
    ) -> String? {
        guard let item = outlineView.item(atRow: row) else { return nil }
        return controller.outlineView(outlineView, objectValueFor: outlineView.tableColumns.first, byItem: item) as? String
    }

    func editorOutlineView(in view: NSView) throws -> NSOutlineView {
        try editorView(in: view, identifier: SnippetsEditorControlIdentifier.outlineView, type: NSOutlineView.self)
    }

    func editorSearchField(in view: NSView) throws -> NSSearchField {
        try editorView(in: view, identifier: SnippetsEditorControlIdentifier.searchField, type: NSSearchField.self)
    }

    func editorTextField(in view: NSView, identifier: NSUserInterfaceItemIdentifier) throws -> NSTextField {
        try editorView(in: view, identifier: identifier, type: NSTextField.self)
    }

    func editorTextView(in view: NSView) throws -> NSTextView {
        try editorView(in: view, identifier: SnippetsEditorControlIdentifier.textView, type: NSTextView.self)
    }

    func editorButton(in view: NSView, identifier: NSUserInterfaceItemIdentifier) throws -> NSButton {
        try editorView(in: view, identifier: identifier, type: NSButton.self)
    }

    func editorView<T: NSView>(
        in view: NSView,
        identifier: NSUserInterfaceItemIdentifier,
        type: T.Type
    ) throws -> T {
        for descendant in view.editorDescendants(ofType: type) where descendant.identifier == identifier {
            return descendant
        }
        return try #require(nil as T?)
    }
}

private extension NSView {
    func editorDescendants<T: NSView>(ofType type: T.Type) -> [T] {
        var descendants = subviews.compactMap { $0 as? T }
        descendants += subviews.flatMap { $0.editorDescendants(ofType: type) }
        if let scrollView = self as? NSScrollView, let documentView = scrollView.documentView {
            descendants += [documentView].compactMap { $0 as? T }
            descendants += documentView.editorDescendants(ofType: type)
        }
        return descendants
    }
}

private final class FakeSnippetRepository: SnippetRepositoryProtocol {
    var folderDetails: [SnippetFolderDetail]
    var searchResults = [String: [SnippetFolderDetail]]()
    var searchQueries = [String]()
    var insertFolderCallCount = 0
    var insertSnippetFolderIDs = [SnippetFolder.ID]()
    var updatedFolderTitles = [SnippetFolder.ID: String]()
    var updatedFolderEnabledStates = [SnippetFolder.ID: Bool]()
    var updatedFolderIndexes = [SnippetFolder.ID]()
    var deletedFolderIDs = [SnippetFolder.ID]()
    var updatedSnippetTitles = [Snippet.ID: String]()
    var updatedSnippetContents = [Snippet.ID: String]()
    var updatedSnippetEnabledStates = [Snippet.ID: Bool]()
    var updatedSnippetIndexes = [Snippet.ID]()
    var movedSnippets = [(id: Snippet.ID, folderID: SnippetFolder.ID, snippetIDs: [Snippet.ID])]()
    var deletedSnippetIDs = [Snippet.ID]()

    init(folderDetails: [SnippetFolderDetail]) {
        self.folderDetails = folderDetails
    }

    func observeFolderDetails() -> NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: SnippetRepository.snippetsDidChangeNotification)
    }

    func fetchFolderDetails() -> [SnippetFolderDetail] {
        folderDetails
    }

    func searchFolderDetails(query: String) -> [SnippetFolderDetail] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        searchQueries.append(query)
        if let result = searchResults[normalizedQuery] {
            return result
        }
        guard !normalizedQuery.isEmpty else { return folderDetails }

        return folderDetails.compactMap { detail in
            if detail.folder.title.lowercased().contains(normalizedQuery) {
                return detail
            }
            let matchingSnippets = detail.snippets.filter { snippet in
                snippet.title.lowercased().contains(normalizedQuery) ||
                    snippet.content.lowercased().contains(normalizedQuery)
            }
            guard !matchingSnippets.isEmpty else { return nil }
            return SnippetFolderDetail(folder: detail.folder, snippets: matchingSnippets)
        }
    }

    func fetchFolderDetail(id: SnippetFolder.ID) -> SnippetFolderDetail? {
        folderDetails.first { $0.folder.id == id }
    }

    func insertFolder() -> SnippetFolder? {
        insertFolderCallCount += 1
        let folder = SnippetFolder(
            id: UUID(),
            title: "New Folder",
            index: folderDetails.count,
            isEnabled: true
        )
        folderDetails.append(SnippetFolderDetail(folder: folder, snippets: []))
        return folder
    }

    func insertFolders(_ folders: [(title: String, snippets: [(title: String, content: String)])]) -> [SnippetFolderDetail]? {
        let transferFolders = folders.map { folder in
            SnippetTransferFolder(
                id: nil,
                title: folder.title,
                index: nil,
                isEnabled: true,
                snippets: folder.snippets.map { snippet in
                    SnippetTransferSnippet(
                        id: nil,
                        title: snippet.title,
                        content: snippet.content,
                        index: nil,
                        isEnabled: true
                    )
                }
            )
        }
        return insertTransferFolders(transferFolders)
    }

    func insertTransferFolders(_ folders: [SnippetTransferFolder]) -> [SnippetFolderDetail]? {
        let inserted = folders.enumerated().map { offset, folderData in
            let folder = SnippetFolder(
                id: UUID(),
                title: folderData.title,
                index: folderData.index ?? folderDetails.count + offset,
                isEnabled: folderData.isEnabled
            )
            let snippets = folderData.snippets.enumerated().map { snippetOffset, snippetData in
                Snippet(
                    id: UUID(),
                    folderID: folder.id,
                    title: snippetData.title,
                    content: snippetData.content,
                    index: snippetData.index ?? snippetOffset,
                    isEnabled: snippetData.isEnabled
                )
            }
            return SnippetFolderDetail(folder: folder, snippets: snippets)
        }
        folderDetails.append(contentsOf: inserted)
        return inserted.isEmpty ? nil : inserted
    }

    func updateFolderTitle(_ id: SnippetFolder.ID, title: String) {
        updatedFolderTitles[id] = title
    }

    func updateFolderIsEnabled(_ id: SnippetFolder.ID, isEnabled: Bool) {
        updatedFolderEnabledStates[id] = isEnabled
    }

    func updateFolderIndexes(_ folderIDs: [SnippetFolder.ID]) {
        updatedFolderIndexes = folderIDs
    }

    func deleteFolder(_ id: SnippetFolder.ID) {
        deletedFolderIDs.append(id)
    }

    func fetchSnippet(id: Snippet.ID) -> Snippet? {
        folderDetails.flatMap(\.snippets).first { $0.id == id }
    }

    func insertSnippet(to id: SnippetFolder.ID) -> Snippet? {
        insertSnippetFolderIDs.append(id)
        guard let folderIndex = folderDetails.firstIndex(where: { $0.folder.id == id }) else { return nil }
        let detail = folderDetails[folderIndex]
        let snippet = Snippet(
            id: UUID(),
            folderID: id,
            title: "New Snippet",
            content: "",
            index: detail.snippets.count,
            isEnabled: true
        )
        folderDetails[folderIndex] = SnippetFolderDetail(
            folder: detail.folder,
            snippets: detail.snippets + [snippet]
        )
        return snippet
    }

    func updateSnippetTitle(_ id: Snippet.ID, title: String) {
        updatedSnippetTitles[id] = title
    }

    func updateSnippetContent(_ id: Snippet.ID, content: String) {
        updatedSnippetContents[id] = content
    }

    func updateSnippetIsEnabled(_ id: Snippet.ID, isEnabled: Bool) {
        updatedSnippetEnabledStates[id] = isEnabled
    }

    func updateSnippetIndexes(_ snippetIDs: [Snippet.ID]) {
        updatedSnippetIndexes = snippetIDs
    }

    func moveSnippet(_ id: Snippet.ID, to folderID: SnippetFolder.ID, snippetIDs: [Snippet.ID]) {
        movedSnippets.append((id: id, folderID: folderID, snippetIDs: snippetIDs))
    }

    func deleteSnippet(_ id: Snippet.ID) {
        deletedSnippetIDs.append(id)
    }
}

private final class FakeSnippetsEditorDialogProvider: SnippetsEditorDialogProviding {
    var confirmDeleteResult: Bool
    var importURL: URL?
    var exportURL: URL?
    var confirmDeleteCallCount = 0
    var importFileCallCount = 0
    var exportFileCallCount = 0
    var defaultExportFileNames = [String]()

    init(
        confirmDeleteResult: Bool = true,
        importURL: URL? = nil,
        exportURL: URL? = nil
    ) {
        self.confirmDeleteResult = confirmDeleteResult
        self.importURL = importURL
        self.exportURL = exportURL
    }

    func confirmDeleteItem() -> Bool {
        confirmDeleteCallCount += 1
        return confirmDeleteResult
    }

    func importFileURL() -> URL? {
        importFileCallCount += 1
        return importURL
    }

    func exportFileURL(defaultFileName: String) -> URL? {
        exportFileCallCount += 1
        defaultExportFileNames.append(defaultFileName)
        return exportURL
    }
}
