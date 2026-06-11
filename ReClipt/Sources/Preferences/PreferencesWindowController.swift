//
//  PreferencesWindowController.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

final class PreferencesWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController: PreferencesWindowController = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Preferences")
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(white: 0.99, alpha: 1)
        return PreferencesWindowController(window: window)
    }()

    private let viewControllers: [NSViewController] = [
        GeneralPreferenceViewController(),
        MenuPreferenceViewController(),
        TypePreferenceViewController(),
        ExcludeAppPreferenceViewController(),
        ShortcutsPreferenceViewController()
    ]

    private var toolbarButtons = [NSButton]()
    private var currentViewController: NSViewController?

    // MARK: - Window Life Cycle
    override func windowDidLoad() {
        super.windowDidLoad()
        setupToolbar()
        switchView(0)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }

    // MARK: - Setup
    private func setupToolbar() {
        guard let contentView = window?.contentView else { return }

        let toolbar = NSView(frame: NSRect(x: 0, y: contentView.frame.height - 50, width: contentView.frame.width, height: 50))
        toolbar.autoresizingMask = [.width, .minYMargin]

        let titles = [
            String(localized: "General"),
            String(localized: "Menu"),
            String(localized: "Type"),
            String(localized: "Exclude"),
            String(localized: "Shortcuts")
        ]

        let buttonWidth = toolbar.frame.width / CGFloat(titles.count)
        for (index, title) in titles.enumerated() {
            let button = NSButton(frame: NSRect(x: CGFloat(index) * buttonWidth, y: 10, width: buttonWidth, height: 30))
            button.title = title
            button.bezelStyle = .texturedRounded
            button.target = self
            button.action = #selector(toolBarItemTapped(_:))
            button.tag = index
            toolbar.addSubview(button)
            toolbarButtons.append(button)
        }

        contentView.addSubview(toolbar)
    }

    @objc private func toolBarItemTapped(_ sender: NSButton) {
        selectedTab(sender.tag)
        switchView(sender.tag)
    }

    private func selectedTab(_ index: Int) {
        toolbarButtons.enumerated().forEach { i, button in
            button.highlight(i == index)
        }
    }

    private func switchView(_ index: Int) {
        guard let contentView = window?.contentView else { return }

        // Remove current view
        currentViewController?.view.removeFromSuperview()

        let newViewController = viewControllers[index]
        let newView = newViewController.view
        newView.frame = NSRect(x: 0, y: 0, width: contentView.frame.width, height: contentView.frame.height - 50)
        newView.autoresizingMask = [.width, .height]
        contentView.addSubview(newView)
        currentViewController = newViewController

        // Resize window to fit content
        let frame = window!.frame
        var newFrame = window!.frameRect(forContentRect: newView.frame)
        newFrame.origin = frame.origin
        newFrame.origin.y += frame.height - newFrame.height - 50
        newFrame.size.height += 50
        window?.setFrame(newFrame, display: true)
    }
}

// MARK: - NSWindow Delegate
extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        NSApp.deactivate()
    }
}

// MARK: - Preference View Controllers (Programmatic)

final class GeneralPreferenceViewController: NSViewController {
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "General Settings"))
        label.font = NSFont.boldSystemFont(ofSize: 16)
        label.frame = NSRect(x: 20, y: 300, width: 200, height: 24)
        view.addSubview(label)

        // Add general settings controls here
    }
}

final class MenuPreferenceViewController: NSViewController {
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Menu Settings"))
        label.font = NSFont.boldSystemFont(ofSize: 16)
        label.frame = NSRect(x: 20, y: 300, width: 200, height: 24)
        view.addSubview(label)

        // Add menu settings controls here
    }
}
