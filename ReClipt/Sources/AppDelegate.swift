//
//  AppDelegate.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    // MARK: - Properties
    private let pasteboardHistoryRepository = PasteboardHistoryRepository()
    private let snippetRepository = SnippetRepository()
    private var pruningTimer: Timer?

    // MARK: - Init
    override init() {
        super.init()
    }

    deinit {
        SQLiteStore.shared.close()
    }

    // MARK: - NSMenuItem Validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(AppDelegate.clearAllHistory) {
            return pasteboardHistoryRepository.hasHistories()
        }
        return true
    }

    // MARK: - Menu Actions
    @objc func showPreferenceWindow() {
        NSApp.activate(ignoringOtherApps: true)
        PreferencesWindowController.sharedController.showWindow(self)
    }

    @objc func showSnippetEditorWindow() {
        NSApp.activate(ignoringOtherApps: true)
        SnippetsEditorWindowController.sharedController.showWindow(self)
    }

    @objc func terminate() {
        terminateApplication()
    }

    @objc func clearAllHistory() {
        let isShowAlert = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showAlertBeforeClearHistory)
        if isShowAlert {
            let alert = NSAlert()
            alert.messageText = String(localized: "Clear History")
            alert.informativeText = String(localized: "Are you sure you want to clear your clipboard history?")
            alert.addButton(withTitle: String(localized: "Clear History"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            alert.showsSuppressionButton = true

            NSApp.activate(ignoringOtherApps: true)

            let result = alert.runModal()
            if result != NSApplication.ModalResponse.alertFirstButtonReturn { return }

            if alert.suppressionButton?.state == NSControl.StateValue.on {
                AppEnvironment.current.defaults.set(false, forKey: Constants.UserDefaults.showAlertBeforeClearHistory)
            }
            AppEnvironment.current.defaults.synchronize()
        }

        AppEnvironment.current.clipService.clearAll()
    }

    @objc func selectHistoryMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? PasteboardHistory.ID, let content = pasteboardHistoryRepository.fetchContent(id: id) else {
            NSSound.beep()
            return
        }

        if AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting) {
            pasteboardHistoryRepository.touchHistory(id: id, updateAt: Int(Date().timeIntervalSince1970))
        }
        AppEnvironment.current.pasteService.paste(id: id, content: content)
    }

    @objc func selectSnippetMenuItem(_ sender: AnyObject) {
        guard let id = sender.representedObject as? Snippet.ID, let snippet = snippetRepository.fetchSnippet(id: id) else {
            NSSound.beep()
            return
        }
        AppEnvironment.current.pasteService.copyToPasteboard(with: snippet.content)
        AppEnvironment.current.pasteService.paste()
    }

    func terminateApplication() {
        NSApplication.shared.terminate(nil)
    }

}

// MARK: - NSApplication Delegate
extension AppDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SQLiteStore.shared.openAsync { result in
            if case .failure(let error) = result {
                print("Failed to open database: \(error)")
            }
        }

        // Environments
        AppEnvironment.replaceCurrent(environment: AppEnvironment.fromStorage())
        // UserDefaults
        ReCliptUtilities.registerUserDefaultKeys()

        // Services
        AppEnvironment.current.clipService.startMonitoring()
        AppEnvironment.current.excludeAppService.startMonitoring()
        AppEnvironment.current.hotKeyService.setupDefaultHotKeys()

        // Managers
        AppEnvironment.current.menuManager.setup()
        runLaunchSmokeIfRequested()

        // Clean histories every 30 minutes
        pruningTimer = Timer.scheduledTimer(withTimeInterval: 60 * 30, repeats: true) { [weak self] _ in
            let maxHistorySize = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxHistorySize)
            self?.pasteboardHistoryRepository.deleteOverflowingHistories(maxHistorySize: maxHistorySize)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.current.clipService.stopMonitoring()
        AppEnvironment.current.excludeAppService.stopMonitoring()
        pruningTimer?.invalidate()
        SQLiteStore.shared.close()
    }
}

private extension AppDelegate {
    func runLaunchSmokeIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--reclipt-smoke-ui") else { return }

        let resultURL = smokeResultURL(from: arguments)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.runLaunchSmoke(resultURL: resultURL)
        }
    }

    func smokeResultURL(from arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--reclipt-smoke-result") else { return nil }
        guard arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    func runLaunchSmoke(resultURL: URL?) {
        var checks = [String]()
        var failures = [String]()

        func record(_ name: String, _ condition: Bool) {
            checks.append("\(condition ? "ok" : "fail") \(name)")
            if !condition {
                failures.append(name)
            }
        }

        showPreferenceWindow()
        showSnippetEditorWindow()

        let preferencesWindow = PreferencesWindowController.sharedController.window
        let snippetsWindow = SnippetsEditorWindowController.sharedController.window
        let statusSetting = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.showStatusItem)
        let shouldShowStatusItem = statusSetting != MenuManager.StatusType.none.rawValue

        record("app-activation-policy-accessory", NSApp.activationPolicy() == .accessory)
        record("menu-manager-built-menus", AppEnvironment.current.menuManager.hasBuiltMenus)
        record("preferences-window-visible", preferencesWindow?.isVisible == true)
        record("preferences-window-title", preferencesWindow?.title == String(localized: "Preferences"))
        record("preferences-window-has-content", preferencesWindow?.contentView?.subviews.isEmpty == false)
        record("preferences-window-size", isUsableWindow(preferencesWindow, minimumSize: NSSize(width: 520, height: 300)))
        record("preferences-toolbar-tabs-present", preferenceToolbarButtons(in: preferencesWindow).count == 6)
        record("preferences-toolbar-tabs-switch", preferenceToolbarButtonsSwitchPanes(in: preferencesWindow))
        record("snippets-window-visible", snippetsWindow?.isVisible == true)
        record("snippets-window-title", snippetsWindow?.title == String(localized: "Edit Snippets"))
        record("snippets-window-has-content", snippetsWindow?.contentView?.subviews.isEmpty == false)
        record("snippets-window-size", isUsableWindow(snippetsWindow, minimumSize: NSSize(width: 520, height: 320)))
        record("snippets-editor-controls-present", snippetsEditorControlsArePresent(in: snippetsWindow))
        record("status-item-setting-matches", AppEnvironment.current.menuManager.hasVisibleStatusItem == shouldShowStatusItem)

        let statusLine = failures.isEmpty ? "ok" : "fail"
        let output = ([statusLine] + checks).joined(separator: "\n") + "\n"

        if let resultURL {
            do {
                try output.write(to: resultURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to write smoke result: \(error)")
            }
        } else {
            print(output)
        }
    }

    func isUsableWindow(_ window: NSWindow?, minimumSize: NSSize) -> Bool {
        guard let window else { return false }
        return window.frame.width >= minimumSize.width && window.frame.height >= minimumSize.height
    }

    func preferenceToolbarButtons(in window: NSWindow?) -> [NSButton] {
        guard let contentView = window?.contentView else { return [] }
        return contentView.descendantViews(compactMap: { view in
            guard let button = view as? NSButton else { return nil }
            guard button.action.map(NSStringFromSelector) == "toolbarButtonTapped:" else { return nil }
            return button
        }).sorted { $0.tag < $1.tag }
    }

    func preferenceToolbarButtonsSwitchPanes(in window: NSWindow?) -> Bool {
        let buttons = preferenceToolbarButtons(in: window)
        guard buttons.count == 5 else { return false }

        for button in buttons {
            button.performClick(nil)
            guard isUsableWindow(window, minimumSize: NSSize(width: 520, height: 300)) else {
                return false
            }
            guard window?.contentView?.subviews.isEmpty == false else {
                return false
            }
        }
        return true
    }

    func snippetsEditorControlsArePresent(in window: NSWindow?) -> Bool {
        guard let contentView = window?.contentView else { return false }
        let requiredIdentifiers = [
            SnippetsEditorControlIdentifier.searchField,
            SnippetsEditorControlIdentifier.addSnippetButton,
            SnippetsEditorControlIdentifier.addFolderButton,
            SnippetsEditorControlIdentifier.deleteButton,
            SnippetsEditorControlIdentifier.importButton,
            SnippetsEditorControlIdentifier.exportButton,
            SnippetsEditorControlIdentifier.sidebarStatusLabel,
            SnippetsEditorControlIdentifier.outlineView,
            SnippetsEditorControlIdentifier.textView
        ]

        return requiredIdentifiers.allSatisfy { identifier in
            contentView.descendantView(withIdentifier: identifier) != nil
        }
    }
}

private extension NSView {
    func descendantView(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        descendantViews { view in
            view.identifier == identifier ? view : nil
        }.first
    }

    func descendantViews<T>(compactMap transform: (NSView) -> T?) -> [T] {
        var matches = [T]()

        if let match = transform(self) {
            matches.append(match)
        }

        for subview in subviews {
            matches.append(contentsOf: subview.descendantViews(compactMap: transform))
        }

        return matches
    }
}
