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
    private var hasConfiguredWindow = false

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

    // MARK: - Setup
    private func configureWindowIfNeeded() {
        guard !hasConfiguredWindow, let window else { return }

        hasConfiguredWindow = true
        window.delegate = self
        window.setFrameAutosaveName("PreferencesWindow")
        setupToolbar()
        selectedTab(0)
        switchView(0)
    }

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

private final class FlippedPreferenceView: NSView {
    override var isFlipped: Bool { true }
}

final class GeneralPreferenceViewController: NSViewController {
    override func loadView() {
        self.view = makeScrollablePreferenceView(title: String(localized: "General Settings")) { stackView in
            stackView.addArrangedSubview(makeCheckboxRow(
                title: String(localized: "Paste after selecting a clip"),
                key: Constants.UserDefaults.inputPasteCommand,
                in: stackView
            ))
            stackView.addArrangedSubview(makeCheckboxRow(
                title: String(localized: "Move pasted clips to the top"),
                key: Constants.UserDefaults.reorderClipsAfterPasting,
                in: stackView
            ))
            stackView.addArrangedSubview(makeCheckboxRow(
                title: String(localized: "Overwrite duplicate clipboard entries"),
                key: Constants.UserDefaults.overwriteSameHistory,
                in: stackView
            ))
            stackView.addArrangedSubview(makeCheckboxRow(
                title: String(localized: "Store duplicate clipboard entries"),
                key: Constants.UserDefaults.copySameHistory,
                in: stackView
            ))
        }
    }
}

final class MenuPreferenceViewController: NSViewController {
    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        let scrollView = NSScrollView(frame: rootView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let contentWidth: CGFloat = 500
        let contentHeight: CGFloat = 680
        let contentView = FlippedPreferenceView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))

        let titleLabel = NSTextField(labelWithString: String(localized: "Menu Settings"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: 20, width: 250, height: 24)
        contentView.addSubview(titleLabel)

        var currentY: CGFloat = 58

        let statusLabel = NSTextField(labelWithString: String(localized: "Menu bar icon style"))
        statusLabel.frame = NSRect(x: 20, y: currentY + 4, width: 200, height: 22)
        contentView.addSubview(statusLabel)

        let statusPopup = NSPopUpButton(frame: NSRect(x: 260, y: currentY, width: 200, height: 26), pullsDown: false)
        statusPopup.addItem(withTitle: String(localized: "Hidden"))
        statusPopup.lastItem?.tag = 0
        statusPopup.addItem(withTitle: String(localized: "Clipboard icon"))
        statusPopup.lastItem?.tag = 1
        statusPopup.addItem(withTitle: String(localized: "Legacy icon"))
        statusPopup.lastItem?.tag = 2
        statusPopup.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.UserDefaults.showStatusItem)
        statusPopup.target = self
        statusPopup.action = #selector(handlePopupSelection(_:))
        statusPopup.selectItem(withTag: UserDefaults.standard.integer(forKey: Constants.UserDefaults.showStatusItem))
        if statusPopup.selectedItem == nil {
            statusPopup.selectItem(withTag: 1)
        }
        contentView.addSubview(statusPopup)

        currentY += 40

        let checkboxes: [(String, String, Bool)] = [
            (String(localized: "Show menu item icons"), Constants.UserDefaults.showIconInTheMenu, false),
            (String(localized: "Add Clear History item"), Constants.UserDefaults.addClearHistoryMenuItem, false),
            (String(localized: "Ask before clearing history"), Constants.UserDefaults.showAlertBeforeClearHistory, false),
            (String(localized: "Show item thumbnails"), Constants.UserDefaults.showImageInTheMenu, false),
            (String(localized: "Show color previews"), Constants.UserDefaults.showColorPreviewInTheMenu, false),
            (String(localized: "Show numbers before menu items"), Constants.UserDefaults.menuItemsAreMarkedWithNumbers, false),
            (String(localized: "Start visible numbering at zero"), Constants.UserDefaults.menuItemsTitleStartWithZero, false),
            (String(localized: "Enable number-key shortcuts"), Constants.UserDefaults.addNumericKeyEquivalents, false),
            (String(localized: "Show tooltips"), Constants.UserDefaults.showToolTipOnMenuItem, false)
        ]

        for (title, key, truthyNonBool) in checkboxes {
            let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(handleCheckboxToggle(_:)))
            checkbox.identifier = NSUserInterfaceItemIdentifier(rawValue: key + (truthyNonBool ? "::truthy" : ""))
            checkbox.state = checkboxState(forKey: key, truthyNonBool: truthyNonBool)
            checkbox.frame = NSRect(x: 20, y: currentY, width: 420, height: 22)
            contentView.addSubview(checkbox)
            currentY += 30
        }

        currentY += 8

        let numericRows: [(String, String, ClosedRange<Int>)] = [
            (String(localized: "Maximum clipboard history size"), Constants.UserDefaults.maxHistorySize, 1...10000),
            (String(localized: "Inline history items"), Constants.UserDefaults.numberOfItemsPlaceInline, 0...100),
            (String(localized: "Items per history folder"), Constants.UserDefaults.numberOfItemsPlaceInsideFolder, 0...100),
            (String(localized: "Menu title length"), Constants.UserDefaults.maxMenuItemTitleLength, 3...1000),
            (String(localized: "Tooltip text length"), Constants.UserDefaults.maxLengthOfToolTip, 1...10000),
            (String(localized: "Thumbnail width"), Constants.UserDefaults.thumbnailWidth, 1...2000),
            (String(localized: "Thumbnail height"), Constants.UserDefaults.thumbnailHeight, 1...2000)
        ]

        for (title, key, range) in numericRows {
            let label = NSTextField(labelWithString: title)
            label.frame = NSRect(x: 20, y: currentY + 4, width: 280, height: 22)
            contentView.addSubview(label)

            let field = NSTextField(frame: NSRect(x: 360, y: currentY, width: 100, height: 26))
            field.alignment = .right
            field.identifier = NSUserInterfaceItemIdentifier(rawValue: key)
            field.target = self
            field.action = #selector(handleNumberFieldChange(_:))
            field.cell?.sendsActionOnEndEditing = true
            field.integerValue = UserDefaults.standard.integer(forKey: key)
            let formatter = NumberFormatter()
            formatter.minimum = NSNumber(value: range.lowerBound)
            formatter.maximum = NSNumber(value: range.upperBound)
            formatter.allowsFloats = false
            formatter.numberStyle = .none
            field.formatter = formatter
            contentView.addSubview(field)

            currentY += 34
        }

        scrollView.documentView = contentView
        contentView.scroll(NSPoint(x: 0, y: 0))
        rootView.addSubview(scrollView)
        self.view = rootView
    }
}

private extension NSViewController {
    func makeScrollablePreferenceView(
        title: String,
        build: (NSStackView) -> Void
    ) -> NSView {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))

        let scrollView = NSScrollView(frame: rootView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        scrollView.documentView = documentView

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 14
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        stackView.addArrangedSubview(titleLabel)

        build(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        rootView.addSubview(scrollView)
        return rootView
    }

    func makeCheckboxRow(
        title: String,
        key: String,
        in stackView: NSStackView,
        truthyNonBool: Bool = false
    ) -> NSView {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.state = checkboxState(forKey: key, truthyNonBool: truthyNonBool)
        button.action = #selector(handleCheckboxToggle(_:))
        button.target = self
        button.identifier = NSUserInterfaceItemIdentifier(rawValue: key + (truthyNonBool ? "::truthy" : ""))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 24))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 460),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func makeNumberRow(
        title: String,
        key: String,
        range: ClosedRange<Int>,
        in stackView: NSStackView
    ) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 28))
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false

        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.alignment = .right
        field.identifier = NSUserInterfaceItemIdentifier(rawValue: key)
        field.target = self
        field.action = #selector(handleNumberFieldChange(_:))
        field.cell?.sendsActionOnEndEditing = true
        field.integerValue = UserDefaults.standard.integer(forKey: key)
        let formatter = NumberFormatter()
        formatter.minimum = NSNumber(value: range.lowerBound)
        formatter.maximum = NSNumber(value: range.upperBound)
        formatter.allowsFloats = false
        formatter.numberStyle = .none
        field.formatter = formatter

        container.addSubview(label)
        container.addSubview(field)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 460),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            field.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            field.widthAnchor.constraint(equalToConstant: 80),
            label.trailingAnchor.constraint(lessThanOrEqualTo: field.leadingAnchor, constant: -12)
        ])
        return container
    }

    @objc func handleCheckboxToggle(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue else { return }
        let components = rawIdentifier.components(separatedBy: "::")
        let key = components[0]
        let truthyNonBool = components.count > 1 && components[1] == "truthy"
        let defaults = AppEnvironment.current.defaults

        if truthyNonBool {
            defaults.set(sender.state == .on ? 1 : 0, forKey: key)
        } else {
            defaults.set(sender.state == .on, forKey: key)
        }
        defaults.synchronize()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
    }

    @objc func handleNumberFieldChange(_ sender: NSTextField) {
        guard let key = sender.identifier?.rawValue else { return }
        let defaults = AppEnvironment.current.defaults
        defaults.set(sender.integerValue, forKey: key)
        defaults.synchronize()
        if key == Constants.UserDefaults.maxHistorySize {
            PasteboardHistoryRepository().deleteOverflowingHistories(maxHistorySize: sender.integerValue)
        }
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
    }

    @objc func handlePopupSelection(_ sender: NSPopUpButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let defaults = AppEnvironment.current.defaults
        defaults.set(sender.selectedItem?.tag ?? 0, forKey: key)
        defaults.synchronize()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
    }

    func checkboxState(forKey key: String, truthyNonBool: Bool) -> NSControl.StateValue {
        let isOn: Bool
        if truthyNonBool {
            isOn = AppEnvironment.current.defaults.integer(forKey: key) != 0
        } else {
            isOn = AppEnvironment.current.defaults.bool(forKey: key)
        }
        return isOn ? .on : .off
    }
}
