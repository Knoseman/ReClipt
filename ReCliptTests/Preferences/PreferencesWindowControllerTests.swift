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
}

private extension NSView {
    func descendantControls<T: NSView>(ofType type: T.Type) -> [T] {
        var controls = subviews.compactMap { $0 as? T }
        controls += subviews.flatMap { $0.descendantControls(ofType: type) }
        return controls
    }
}

private final class NotificationRecorder: NSObject {
    var notification: Notification?

    @objc func record(_ notification: Notification) {
        self.notification = notification
    }
}
