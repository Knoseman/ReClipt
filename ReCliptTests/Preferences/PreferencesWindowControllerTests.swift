//
//  PreferencesWindowControllerTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/14.
//
//  Copyright © 2026 ReClipt Project.
//

import AppKit
import Testing
@testable import ReClipt

@MainActor
@Suite(.serialized)
struct PreferencesWindowControllerTests {
    @Test
    func preferencesWindowSwitchesBetweenAllPanes() throws {
        let controller = makePreferencesWindowController()
        defer { controller.close() }
        let contentView = try #require(controller.window?.contentView)

        let expectedPaneLabels = [
            "Behavior",
            "Layout",
            "Clipboard Types",
            "Excluded Applications",
            "Main Menu:",
            "Export Backup"
        ]

        for (index, label) in expectedPaneLabels.enumerated() {
            let button = try preferenceTabButton(in: contentView, tag: index)
            button.sendAction(button.action, to: button.target)

            #expect(contentView.descendantLabels().contains(label))
            #expect(button.layer?.borderWidth == 1)
        }
    }

    @Test
    func preferencesToolbarStaysAlignedAcrossPaneSwitches() throws {
        let controller = makePreferencesWindowController()
        defer { controller.close() }
        let contentView = try #require(controller.window?.contentView)

        let initialButtonFrames = try preferenceTabButtons(in: contentView)
            .map(\.frame)

        for index in 0..<6 {
            let button = try preferenceTabButton(in: contentView, tag: index)
            button.sendAction(button.action, to: button.target)

            let frames = try preferenceTabButtons(in: contentView).map(\.frame)
            #expect(frames == initialButtonFrames)
        }
    }

    @Test
    func generalPaneReflectsStoredDefaults() throws {
        let defaults = try pushPreferencesTestEnvironment("GeneralPaneReflectsStoredDefaults")
        defer { popPreferencesTestEnvironment(defaults, suiteName: "GeneralPaneReflectsStoredDefaults") }

        defaults.set(false, forKey: Constants.UserDefaults.inputPasteCommand)
        defaults.set(42, forKey: Constants.UserDefaults.maxHistorySize)
        defaults.set(2, forKey: Constants.UserDefaults.showStatusItem)

        let view = GeneralPreferenceViewController().view
        let pasteCheckbox = try preferenceCheckbox(
            in: view,
            identifier: Constants.UserDefaults.inputPasteCommand
        )
        let maxHistoryField = try preferenceTextField(
            in: view,
            identifier: Constants.UserDefaults.maxHistorySize
        )
        let statusPopup = try preferencePopup(
            in: view,
            identifier: Constants.UserDefaults.showStatusItem
        )

        #expect(pasteCheckbox.state == .off)
        #expect(maxHistoryField.integerValue == 42)
        #expect(statusPopup.selectedItem?.tag == 2)
    }

    @Test
    func checkboxToggleWritesDefaultAndPostsChangeNotification() throws {
        let defaults = try pushPreferencesTestEnvironment("CheckboxToggleWritesDefaultAndPostsChangeNotification")
        defer { popPreferencesTestEnvironment(defaults, suiteName: "CheckboxToggleWritesDefaultAndPostsChangeNotification") }

        defaults.set(false, forKey: Constants.UserDefaults.showIconInTheMenu)
        let viewController = MenuPreferenceViewController()
        let checkbox = try preferenceCheckbox(
            in: viewController.view,
            identifier: Constants.UserDefaults.showIconInTheMenu
        )
        checkbox.state = .on

        let notification = try waitForDefaultsChange(object: defaults) {
            checkbox.sendAction(checkbox.action, to: checkbox.target)
        }

        #expect(notification.object as? UserDefaults === defaults)
        #expect(defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu))
    }

    @Test
    func numberFieldWritesDefaultPostsChangeNotificationAndPrunesHistory() throws {
        try TestSQLiteStore.withCleanStore {
            let defaults = try pushPreferencesTestEnvironment("NumberFieldWritesDefaultPostsChangeNotificationAndPrunesHistory")
            defer { popPreferencesTestEnvironment(defaults, suiteName: "NumberFieldWritesDefaultPostsChangeNotificationAndPrunesHistory") }

            let repository = PasteboardHistoryRepository()
            for index in 0..<5 {
                let content = try #require(
                    PasteboardContent(assets: [PasteboardContent.Asset(type: .string, data: Data("Clip \(index)".utf8))])
                )
                repository.save(id: "preference-\(index)", content: content, updateAt: 1000 + index)
            }

            let viewController = GeneralPreferenceViewController()
            let field = try preferenceTextField(
                in: viewController.view,
                identifier: Constants.UserDefaults.maxHistorySize
            )
            field.integerValue = 2

            let notification = try waitForDefaultsChange(object: defaults) {
                field.sendAction(field.action, to: field.target)
            }

            #expect(notification.object as? UserDefaults === defaults)
            #expect(defaults.integer(forKey: Constants.UserDefaults.maxHistorySize) == 2)
            #expect(repository.count() == 2)
            #expect(repository.fetchHistory(id: "preference-4") != nil)
            #expect(repository.fetchHistory(id: "preference-3") != nil)
            #expect(repository.fetchHistory(id: "preference-2") == nil)
        }
    }

    @Test
    func popupSelectionWritesDefaultAndPostsChangeNotification() throws {
        let defaults = try pushPreferencesTestEnvironment("PopupSelectionWritesDefaultAndPostsChangeNotification")
        defer { popPreferencesTestEnvironment(defaults, suiteName: "PopupSelectionWritesDefaultAndPostsChangeNotification") }

        defaults.set(0, forKey: Constants.UserDefaults.showStatusItem)
        let viewController = GeneralPreferenceViewController()
        let popup = try preferencePopup(
            in: viewController.view,
            identifier: Constants.UserDefaults.showStatusItem
        )
        popup.selectItem(withTag: 1)

        let notification = try waitForDefaultsChange(object: defaults) {
            popup.sendAction(popup.action, to: popup.target)
        }

        #expect(notification.object as? UserDefaults === defaults)
        #expect(defaults.integer(forKey: Constants.UserDefaults.showStatusItem) == 1)
    }

    @Test
    func backupPaneAppearsInToolbar() throws {
        let controller = makePreferencesWindowController()
        defer { controller.close() }
        let contentView = try #require(controller.window?.contentView)

        let button = try preferenceTabButton(in: contentView, tag: 5)
        button.sendAction(button.action, to: button.target)

        #expect(contentView.descendantLabels().contains("Export Backup"))
        #expect(contentView.descendantLabels().contains("Restore Backup"))
    }

    @Test
    func backupPaneControlsExistAndDefaultToSafeStates() throws {
        let view = BackupPreferenceViewController().view
        let settingsCheckbox = try preferenceCheckbox(in: view, identifier: BackupPreferenceControlIdentifier.exportSettingsCheckbox.rawValue)
        let snippetsCheckbox = try preferenceCheckbox(in: view, identifier: BackupPreferenceControlIdentifier.exportSnippetsCheckbox.rawValue)
        let historyCheckbox = try preferenceCheckbox(in: view, identifier: BackupPreferenceControlIdentifier.exportHistoryCheckbox.rawValue)
        _ = try preferenceButton(in: view, identifier: BackupPreferenceControlIdentifier.exportButton.rawValue)
        _ = try preferenceButton(in: view, identifier: BackupPreferenceControlIdentifier.restoreButton.rawValue)

        #expect(settingsCheckbox.state == .on)
        #expect(snippetsCheckbox.state == .on)
        #expect(historyCheckbox.state == .off)
        #expect(view.descendantLabels().contains("Clipboard history can contain private content. Include it only when needed."))
    }

    @Test
    func backupExportPassesSelectedSectionsToInjectedService() throws {
        let service = FakePreferencesBackupService()
        let dialogs = FakePreferencesBackupDialogs()
        dialogs.exportURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Export.recliptbackup")
        let viewController = BackupPreferenceViewController(service: service, dialogProvider: dialogs)
        let view = viewController.view
        let exportButton = try preferenceButton(in: view, identifier: BackupPreferenceControlIdentifier.exportButton.rawValue)

        exportButton.sendAction(exportButton.action, to: exportButton.target)

        #expect(service.exportedURL == dialogs.exportURL)
        #expect(service.exportedSections == [.settings, .snippets])
        #expect(dialogs.successMessages == ["Backup exported"])
    }

    @Test
    func backupRestorePreviewsConfirmsHistoryAndRestoresSelectedSections() throws {
        let service = FakePreferencesBackupService()
        let dialogs = FakePreferencesBackupDialogs()
        let restoreURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Restore.recliptbackup")
        let preview = PreferencesBackupPreview(
            appVersion: "1.2.3",
            exportedAt: Date(timeIntervalSince1970: 100),
            includesSettings: true,
            includesSnippets: true,
            snippetCount: 4,
            includesHistory: true,
            historyCount: 7
        )
        service.preview = preview
        dialogs.restoreURL = restoreURL
        dialogs.restoreSections = [.settings, .history]
        dialogs.confirmHistory = true
        let viewController = BackupPreferenceViewController(service: service, dialogProvider: dialogs)
        let view = viewController.view
        let restoreButton = try preferenceButton(in: view, identifier: BackupPreferenceControlIdentifier.restoreButton.rawValue)

        let historyNotification = try waitForNotification(name: PasteboardHistoryRepository.historyDidChangeNotification) {
            restoreButton.sendAction(restoreButton.action, to: restoreButton.target)
        }

        #expect(service.previewedURL == restoreURL)
        #expect(dialogs.previewForRestore == preview)
        #expect(dialogs.didConfirmHistory)
        #expect(service.restoredURL == restoreURL)
        #expect(service.restoredSections == [.settings, .history])
        #expect(historyNotification.name == PasteboardHistoryRepository.historyDidChangeNotification)
        #expect(dialogs.successMessages == ["Backup restored"])
    }

    @Test
    func typePaneReflectsAndWritesStoreTypeDefaults() throws {
        let defaults = try pushPreferencesTestEnvironment("TypePaneReflectsAndWritesStoreTypeDefaults")
        defer { popPreferencesTestEnvironment(defaults, suiteName: "TypePaneReflectsAndWritesStoreTypeDefaults") }

        var storeTypes = [String: Bool]()
        for type in PasteboardAvailableType.allCases {
            storeTypes[type.rawValue] = true
        }
        defaults.set(storeTypes, forKey: Constants.UserDefaults.storeTypes)

        let viewController = TypePreferenceViewController()
        let pngCheckbox = try preferenceCheckbox(
            in: viewController.view,
            title: PasteboardAvailableType.tiff.rawValue
        )

        #expect(pngCheckbox.state == .on)

        pngCheckbox.state = .off
        pngCheckbox.sendAction(pngCheckbox.action, to: pngCheckbox.target)

        let updatedTypes = try #require(defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: Bool])
        #expect(updatedTypes[PasteboardAvailableType.tiff.rawValue] == false)
    }
}

private extension PreferencesWindowControllerTests {
    func makePreferencesWindowController() -> PreferencesWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let controller = PreferencesWindowController(window: window)
        controller.showWindow(nil)
        return controller
    }

    func preferenceTabButton(in view: NSView, tag: Int) throws -> NSButton {
        try #require(preferenceTabButtons(in: view).first { $0.tag == tag })
    }

    func preferenceTabButtons(in view: NSView) throws -> [NSButton] {
        let buttons = view.descendantControls(ofType: NSButton.self)
            .filter { $0.title.isEmpty && !$0.isBordered && $0.tag >= 0 && $0.tag < 6 && $0.action != nil }
            .sorted { $0.tag < $1.tag }
        #expect(buttons.count == 6)
        return buttons
    }

    func pushPreferencesTestEnvironment(_ suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        AppEnvironment.push(defaults: defaults)
        return defaults
    }

    func popPreferencesTestEnvironment(_ defaults: UserDefaults, suiteName: String) {
        _ = AppEnvironment.popLast()
        defaults.removePersistentDomain(forName: suiteName)
    }

    func waitForDefaultsChange(
        object: UserDefaults,
        action: () -> Void
    ) throws -> Notification {
        let recorder = NotificationRecorder()
        NotificationCenter.default.addObserver(
            recorder,
            selector: #selector(NotificationRecorder.record(_:)),
            name: UserDefaults.didChangeNotification,
            object: object
        )
        defer {
            NotificationCenter.default.removeObserver(recorder)
        }

        action()

        return try #require(recorder.notification)
    }

    func waitForNotification(
        name: Notification.Name,
        action: () -> Void
    ) throws -> Notification {
        let recorder = NotificationRecorder()
        NotificationCenter.default.addObserver(
            recorder,
            selector: #selector(NotificationRecorder.record(_:)),
            name: name,
            object: nil
        )
        defer {
            NotificationCenter.default.removeObserver(recorder)
        }

        action()

        return try #require(recorder.notification)
    }

    func preferenceCheckbox(in view: NSView, identifier: String) throws -> NSButton {
        for button in view.descendantControls(ofType: NSButton.self) where button.identifier?.rawValue == identifier {
            return button
        }
        return try #require(nil as NSButton?)
    }

    func preferenceCheckbox(in view: NSView, title: String) throws -> NSButton {
        for button in view.descendantControls(ofType: NSButton.self) where button.title == title {
            return button
        }
        return try #require(nil as NSButton?)
    }

    func preferenceTextField(in view: NSView, identifier: String) throws -> NSTextField {
        for field in view.descendantControls(ofType: NSTextField.self) where field.identifier?.rawValue == identifier {
            return field
        }
        return try #require(nil as NSTextField?)
    }

    func preferencePopup(in view: NSView, identifier: String) throws -> NSPopUpButton {
        for popup in view.descendantControls(ofType: NSPopUpButton.self) where popup.identifier?.rawValue == identifier {
            return popup
        }
        return try #require(nil as NSPopUpButton?)
    }

    func preferenceButton(in view: NSView, identifier: String) throws -> NSButton {
        for button in view.descendantControls(ofType: NSButton.self) where button.identifier?.rawValue == identifier {
            return button
        }
        return try #require(nil as NSButton?)
    }
}

private final class FakePreferencesBackupService: PreferencesBackupServicing {
    var exportedURL: URL?
    var exportedSections: Set<BackupPreferenceSection>?
    var previewedURL: URL?
    var preview = PreferencesBackupPreview()
    var restoredURL: URL?
    var restoredSections: Set<BackupPreferenceSection>?

    func exportBackup(to url: URL, sections: Set<BackupPreferenceSection>) throws {
        exportedURL = url
        exportedSections = sections
    }

    func previewBackup(at url: URL) throws -> PreferencesBackupPreview {
        previewedURL = url
        return preview
    }

    func restoreBackup(from url: URL, sections: Set<BackupPreferenceSection>) throws {
        restoredURL = url
        restoredSections = sections
    }
}

private final class FakePreferencesBackupDialogs: PreferencesBackupDialogProviding {
    var exportURL: URL?
    var restoreURL: URL?
    var restoreSections: Set<BackupPreferenceSection>?
    var previewForRestore: PreferencesBackupPreview?
    var confirmHistory = false
    var didConfirmHistory = false
    var successMessages = [String]()
    var failureMessages = [String]()

    func chooseExportURL(window: NSWindow?) -> URL? {
        exportURL
    }

    func chooseRestoreURL(window: NSWindow?) -> URL? {
        restoreURL
    }

    func chooseRestoreSections(for preview: PreferencesBackupPreview, window: NSWindow?) -> Set<BackupPreferenceSection>? {
        previewForRestore = preview
        return restoreSections
    }

    func confirmRestoreClipboardHistory(window: NSWindow?) -> Bool {
        didConfirmHistory = true
        return confirmHistory
    }

    func showSuccess(message: String, informativeText: String, window: NSWindow?) {
        successMessages.append(message)
    }

    func showFailure(message: String, informativeText: String, window: NSWindow?) {
        failureMessages.append(message)
    }
}

private extension NSView {
    func descendantControls<T: NSView>(ofType type: T.Type) -> [T] {
        var controls = subviews.compactMap { $0 as? T }
        controls += subviews.flatMap { $0.descendantControls(ofType: type) }
        return controls
    }

    func descendantLabels() -> [String] {
        descendantControls(ofType: NSTextField.self)
            .filter { !$0.isEditable }
            .map(\.stringValue)
    }
}

private final class NotificationRecorder: NSObject {
    var notification: Notification?

    @objc func record(_ notification: Notification) {
        self.notification = notification
    }
}
