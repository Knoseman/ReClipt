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
import UniformTypeIdentifiers

// MARK: - Backup Preferences Contracts

enum BackupPreferenceSection: String, CaseIterable, Hashable {
    case settings
    case snippets
    case history

    var title: String {
        switch self {
        case .settings:
            return String(localized: "Settings")
        case .snippets:
            return String(localized: "Snippets")
        case .history:
            return String(localized: "Clipboard history")
        }
    }
}

struct PreferencesBackupPreview: Equatable {
    var appVersion: String?
    var exportedAt: Date?
    var includesSettings: Bool
    var includesSnippets: Bool
    var snippetCount: Int
    var includesHistory: Bool
    var historyCount: Int

    init(
        appVersion: String? = nil,
        exportedAt: Date? = nil,
        includesSettings: Bool = false,
        includesSnippets: Bool = false,
        snippetCount: Int = 0,
        includesHistory: Bool = false,
        historyCount: Int = 0
    ) {
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.includesSettings = includesSettings
        self.includesSnippets = includesSnippets
        self.snippetCount = snippetCount
        self.includesHistory = includesHistory
        self.historyCount = historyCount
    }

    var availableSections: Set<BackupPreferenceSection> {
        var sections = Set<BackupPreferenceSection>()
        if includesSettings { sections.insert(.settings) }
        if includesSnippets { sections.insert(.snippets) }
        if includesHistory { sections.insert(.history) }
        return sections
    }
}

protocol PreferencesBackupServicing {
    func exportBackup(to url: URL, sections: Set<BackupPreferenceSection>) throws
    func previewBackup(at url: URL) throws -> PreferencesBackupPreview
    func restoreBackup(from url: URL, sections: Set<BackupPreferenceSection>) throws
}

protocol PreferencesBackupDialogProviding {
    func chooseExportURL(window: NSWindow?) -> URL?
    func chooseRestoreURL(window: NSWindow?) -> URL?
    func chooseRestoreSections(for preview: PreferencesBackupPreview, window: NSWindow?) -> Set<BackupPreferenceSection>?
    func confirmRestoreClipboardHistory(window: NSWindow?) -> Bool
    func showSuccess(message: String, informativeText: String, window: NSWindow?)
    func showFailure(message: String, informativeText: String, window: NSWindow?)
}

struct BackupServicePreferencesAdapter: PreferencesBackupServicing {
    let service: BackupService

    init(service: BackupService = BackupService()) {
        self.service = service
    }

    func exportBackup(to url: URL, sections: Set<BackupPreferenceSection>) throws {
        try service.exportBackup(to: url, sections: sections.backupSections)
    }

    func previewBackup(at url: URL) throws -> PreferencesBackupPreview {
        let preview = try service.previewBackup(at: url)
        return PreferencesBackupPreview(
            appVersion: preview.appVersion,
            exportedAt: preview.exportedAt,
            includesSettings: preview.sections.contains(.settings),
            includesSnippets: preview.sections.contains(.snippets),
            snippetCount: preview.snippetCount,
            includesHistory: preview.sections.contains(.history),
            historyCount: preview.historyItemCount
        )
    }

    func restoreBackup(from url: URL, sections: Set<BackupPreferenceSection>) throws {
        try service.restoreBackup(from: url, sections: sections.backupSections)
    }
}

private extension Set where Element == BackupPreferenceSection {
    var backupSections: Set<BackupSection> {
        Set<BackupSection>(map { $0.backupSection })
    }
}

private extension BackupPreferenceSection {
    var backupSection: BackupSection {
        switch self {
        case .settings: return .settings
        case .snippets: return .snippets
        case .history: return .history
        }
    }
}

enum BackupPreferenceControlIdentifier {
    static let exportSettingsCheckbox = NSUserInterfaceItemIdentifier("Preferences.Backup.export.settings")
    static let exportSnippetsCheckbox = NSUserInterfaceItemIdentifier("Preferences.Backup.export.snippets")
    static let exportHistoryCheckbox = NSUserInterfaceItemIdentifier("Preferences.Backup.export.history")
    static let exportButton = NSUserInterfaceItemIdentifier("Preferences.Backup.export.button")
    static let restoreButton = NSUserInterfaceItemIdentifier("Preferences.Backup.restore.button")
}

private enum BackupPreferenceError: LocalizedError {
    case serviceUnavailable
    case noExportSections
    case noRestoreSections

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return String(localized: "Backup service is not available yet.")
        case .noExportSections:
            return String(localized: "Select at least one section to export.")
        case .noRestoreSections:
            return String(localized: "Select at least one section to restore.")
        }
    }
}

final class PreferencesWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController: PreferencesWindowController = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Preferences")
        window.titlebarAppearsTransparent = true
        return PreferencesWindowController(window: window)
    }()

    private struct Pane {
        let title: String
        let systemImageName: String
        let viewController: NSViewController
    }

    private let toolbarHeight: CGFloat = 64
    private let panes: [Pane]

    private var toolbarView: NSView?
    private var toolbarButtons = [PreferenceTabButton]()
    private var currentViewController: NSViewController?
    private var selectedIndex = 0
    private var hasConfiguredWindow = false

    init(
        window: NSWindow?,
        backupService: PreferencesBackupServicing? = BackupServicePreferencesAdapter(),
        backupDialogProvider: PreferencesBackupDialogProviding = AppKitPreferencesBackupDialogProvider()
    ) {
        self.panes = [
            Pane(title: String(localized: "General"), systemImageName: "switch.2", viewController: GeneralPreferenceViewController()),
            Pane(title: String(localized: "Menu"), systemImageName: "list.bullet", viewController: MenuPreferenceViewController()),
            Pane(title: String(localized: "Type"), systemImageName: "doc.text", viewController: TypePreferenceViewController()),
            Pane(title: String(localized: "Exclude"), systemImageName: "nosign", viewController: ExcludeAppPreferenceViewController()),
            Pane(title: String(localized: "Shortcuts"), systemImageName: "keyboard", viewController: ShortcutsPreferenceViewController()),
            Pane(title: String(localized: "Backup"), systemImageName: "externaldrive", viewController: BackupPreferenceViewController(service: backupService, dialogProvider: backupDialogProvider))
        ]
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    // MARK: - Setup
    private func configureWindowIfNeeded() {
        guard !hasConfiguredWindow, let window else { return }

        hasConfiguredWindow = true
        window.delegate = self
        window.setFrameAutosaveName("PreferencesWindow")
        setupToolbar()
        switchView(0)
    }

    private func setupToolbar() {
        guard let contentView = window?.contentView else { return }

        let toolbar = NSView(frame: NSRect(x: 0, y: 0, width: contentView.frame.width, height: toolbarHeight))
        toolbar.autoresizingMask = [.width, .minYMargin]

        for (index, pane) in panes.enumerated() {
            let button = PreferenceTabButton(
                title: pane.title,
                image: NSImage(systemSymbolName: pane.systemImageName, accessibilityDescription: pane.title)
            )
            button.target = self
            button.action = #selector(toolbarButtonTapped(_:))
            button.tag = index
            toolbar.addSubview(button)
            toolbarButtons.append(button)
        }

        contentView.addSubview(toolbar)
        toolbarView = toolbar
    }

    private func layoutToolbar(width: CGFloat, contentHeight: CGFloat) {
        guard let toolbarView else { return }

        toolbarView.frame = NSRect(x: 0, y: contentHeight, width: width, height: toolbarHeight)

        let buttonWidth: CGFloat = 72
        let buttonHeight: CGFloat = 48
        let gap: CGFloat = 12
        let totalWidth = CGFloat(toolbarButtons.count) * buttonWidth + CGFloat(toolbarButtons.count - 1) * gap
        var x = max(12, (width - totalWidth) / 2)

        for button in toolbarButtons {
            button.frame = NSRect(x: x, y: 8, width: buttonWidth, height: buttonHeight)
            x += buttonWidth + gap
        }
    }

    @objc private func toolbarButtonTapped(_ sender: NSButton) {
        switchView(sender.tag)
    }

    private func selectedTab(_ index: Int) {
        toolbarButtons.enumerated().forEach { i, button in
            button.isSelected = i == index
        }
    }

    private func switchView(_ index: Int) {
        guard panes.indices.contains(index), let window, let contentView = window.contentView else { return }

        selectedIndex = index
        selectedTab(index)
        currentViewController?.view.removeFromSuperview()

        let newViewController = panes[index].viewController
        let newView = newViewController.view
        let paneWidth = max(CGFloat(640), newView.frame.width)
        let paneHeight = newView.frame.height
        let contentSize = NSSize(width: paneWidth, height: paneHeight + toolbarHeight)

        let oldFrame = window.frame
        var newFrame = window.frameRect(forContentRect: NSRect(origin: oldFrame.origin, size: contentSize))
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = oldFrame.origin.y + oldFrame.height - newFrame.height
        window.setFrame(newFrame, display: true, animate: true)

        contentView.frame = NSRect(origin: .zero, size: contentSize)
        newView.frame = NSRect(x: 0, y: 0, width: paneWidth, height: paneHeight)
        newView.autoresizingMask = [.width, .height]
        contentView.addSubview(newView)
        currentViewController = newViewController

        layoutToolbar(width: paneWidth, contentHeight: paneHeight)
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

// MARK: - Preference View Controllers

private final class FlippedPreferenceView: NSView {
    override var isFlipped: Bool { true }
}

private final class PreferenceTabButton: NSButton {
    private let iconView = NSImageView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")

    var isSelected = false {
        didSet { updateAppearance() }
    }

    init(title: String, image: NSImage?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 72, height: 48))
        self.title = ""
        self.isBordered = false
        self.focusRingType = .none
        self.wantsLayer = true

        iconView.image = image
        iconView.image?.isTemplate = true
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.stringValue = title
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 3),
            titleLabel.heightAnchor.constraint(equalToConstant: 15)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        super.updateLayer()
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let textColor = isSelected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        let iconColor = isSelected ? NSColor.controlAccentColor : NSColor.labelColor

        titleLabel.textColor = textColor
        iconView.contentTintColor = iconColor

        layer?.cornerRadius = 6
        layer?.borderWidth = isSelected ? 1 : 0
        layer?.borderColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.45).cgColor : nil
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
            : NSColor.clear.cgColor
    }
}

final class GeneralPreferenceViewController: NSViewController {
    override func loadView() {
        let view = makePreferencePane(height: 300)
        var y: CGFloat = 24

        addSectionLabel(String(localized: "Behavior"), y: &y, to: view)
        addCheckbox(String(localized: "Paste after selecting a clip"), key: Constants.UserDefaults.inputPasteCommand, y: &y, to: view)
        addCheckbox(String(localized: "Move pasted clips to the top"), key: Constants.UserDefaults.reorderClipsAfterPasting, y: &y, to: view)
        addCheckbox(String(localized: "Overwrite duplicate clipboard entries"), key: Constants.UserDefaults.overwriteSameHistory, y: &y, to: view)
        addCheckbox(String(localized: "Store duplicate clipboard entries"), key: Constants.UserDefaults.copySameHistory, y: &y, to: view)

        y += 10
        addSectionLabel(String(localized: "Clipboard History"), y: &y, to: view)
        addNumberRow(
            String(localized: "Maximum clipboard history size:"),
            key: Constants.UserDefaults.maxHistorySize,
            range: 1...10000,
            unit: String(localized: "items"),
            y: &y,
            to: view
        )

        y += 10
        addSectionLabel(String(localized: "Appearance"), y: &y, to: view)
        addPopupRow(
            String(localized: "Menu bar icon style:"),
            key: Constants.UserDefaults.showStatusItem,
            options: [
                (String(localized: "Hidden"), 0),
                (String(localized: "Clipboard icon"), 1),
                (String(localized: "Legacy icon"), 2)
            ],
            y: &y,
            to: view
        )

        self.view = view
    }
}

final class MenuPreferenceViewController: NSViewController {
    override func loadView() {
        let view = makePreferencePane(height: 350)
        var leftY: CGFloat = 24
        var rightY: CGFloat = 24

        addSectionLabel(String(localized: "Layout"), y: &leftY, to: view, x: 48, width: 260)
        addNumberRow(String(localized: "Inline history items:"), key: Constants.UserDefaults.numberOfItemsPlaceInline, range: 0...100, unit: String(localized: "items"), y: &leftY, to: view, x: 48, fieldX: 236, labelWidth: 170)
        addNumberRow(String(localized: "Items per history folder:"), key: Constants.UserDefaults.numberOfItemsPlaceInsideFolder, range: 0...100, unit: String(localized: "items"), y: &leftY, to: view, x: 48, fieldX: 236, labelWidth: 170)
        addNumberRow(String(localized: "Menu title length:"), key: Constants.UserDefaults.maxMenuItemTitleLength, range: 3...1000, unit: String(localized: "chars"), y: &leftY, to: view, x: 48, fieldX: 236, labelWidth: 170)

        leftY += 10
        addSectionLabel(String(localized: "Numbering & Shortcuts"), y: &leftY, to: view, x: 48, width: 260)
        addCheckbox(String(localized: "Show numbers before menu items"), key: Constants.UserDefaults.menuItemsAreMarkedWithNumbers, y: &leftY, to: view, x: 48, width: 260)
        addCheckbox(String(localized: "Start visible numbering at zero"), key: Constants.UserDefaults.menuItemsTitleStartWithZero, y: &leftY, to: view, x: 48, width: 260)
        addCheckbox(String(localized: "Enable number-key shortcuts"), key: Constants.UserDefaults.addNumericKeyEquivalents, y: &leftY, to: view, x: 48, width: 260)

        leftY += 10
        addSectionLabel(String(localized: "Commands"), y: &leftY, to: view, x: 48, width: 260)
        addCheckbox(String(localized: "Add Clear History item"), key: Constants.UserDefaults.addClearHistoryMenuItem, y: &leftY, to: view, x: 48, width: 260)
        addCheckbox(String(localized: "Ask before clearing history"), key: Constants.UserDefaults.showAlertBeforeClearHistory, y: &leftY, to: view, x: 48, width: 260)

        addSectionLabel(String(localized: "Previews"), y: &rightY, to: view, x: 348, width: 240)
        addCheckbox(String(localized: "Show menu item icons"), key: Constants.UserDefaults.showIconInTheMenu, y: &rightY, to: view, x: 348, width: 240)
        addCheckbox(String(localized: "Show item thumbnails"), key: Constants.UserDefaults.showImageInTheMenu, y: &rightY, to: view, x: 348, width: 240)
        addCheckbox(String(localized: "Show color previews"), key: Constants.UserDefaults.showColorPreviewInTheMenu, y: &rightY, to: view, x: 348, width: 240)
        addNumberRow(String(localized: "Thumbnail width:"), key: Constants.UserDefaults.thumbnailWidth, range: 1...2000, unit: String(localized: "px"), y: &rightY, to: view, x: 348, fieldX: 486, labelWidth: 130)
        addNumberRow(String(localized: "Thumbnail height:"), key: Constants.UserDefaults.thumbnailHeight, range: 1...2000, unit: String(localized: "px"), y: &rightY, to: view, x: 348, fieldX: 486, labelWidth: 130)

        rightY += 10
        addSectionLabel(String(localized: "Tooltips"), y: &rightY, to: view, x: 348, width: 240)
        addCheckbox(String(localized: "Show tooltips"), key: Constants.UserDefaults.showToolTipOnMenuItem, y: &rightY, to: view, x: 348, width: 240)
        addNumberRow(String(localized: "Tooltip text length:"), key: Constants.UserDefaults.maxLengthOfToolTip, range: 1...10000, unit: String(localized: "chars"), y: &rightY, to: view, x: 348, fieldX: 486, labelWidth: 130)

        self.view = view
    }
}

struct AppKitPreferencesBackupDialogProvider: PreferencesBackupDialogProviding {
    private static let backupContentType = UTType(filenameExtension: "recliptbackup") ?? .json

    func chooseExportURL(window: NSWindow?) -> URL? {
        let panel = NSSavePanel()
        panel.title = String(localized: "Export Backup")
        panel.prompt = String(localized: "Export")
        panel.nameFieldStringValue = "ReClipt Backup.recliptbackup"
        panel.allowedContentTypes = [Self.backupContentType]
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseRestoreURL(window: NSWindow?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Restore Backup")
        panel.prompt = String(localized: "Restore")
        panel.allowedContentTypes = [Self.backupContentType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseRestoreSections(for preview: PreferencesBackupPreview, window: NSWindow?) -> Set<BackupPreferenceSection>? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Restore Backup")
        alert.informativeText = previewText(for: preview)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Restore"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        var checkboxes = [BackupPreferenceSection: NSButton]()
        for section in BackupPreferenceSection.allCases {
            let checkbox = NSButton(checkboxWithTitle: section.title, target: nil, action: nil)
            checkbox.state = preview.availableSections.contains(section) ? .on : .off
            checkbox.isEnabled = preview.availableSections.contains(section)
            checkboxes[section] = checkbox
            stack.addArrangedSubview(checkbox)
        }
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: 90)
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return Set(checkboxes.compactMap { section, checkbox in
            checkbox.state == .on && checkbox.isEnabled ? section : nil
        })
    }

    func confirmRestoreClipboardHistory(window: NSWindow?) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Restore clipboard history?")
        alert.informativeText = String(localized: "Clipboard history can contain private content. Only restore it from backup files you trust.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Restore History"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    func showSuccess(message: String, informativeText: String, window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    func showFailure(message: String, informativeText: String, window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func previewText(for preview: PreferencesBackupPreview) -> String {
        var lines = [String(localized: "Review the backup contents before restoring.")]
        if let appVersion = preview.appVersion, !appVersion.isEmpty {
            lines.append(String(format: String(localized: "App version: %@"), appVersion))
        }
        if let exportedAt = preview.exportedAt {
            lines.append(String(format: String(localized: "Exported: %@"), DateFormatter.localizedString(from: exportedAt, dateStyle: .medium, timeStyle: .short)))
        }
        lines.append(preview.includesSettings ? String(localized: "Settings: included") : String(localized: "Settings: not included"))
        lines.append(preview.includesSnippets ? String(format: String(localized: "Snippets: %d"), preview.snippetCount) : String(localized: "Snippets: not included"))
        lines.append(preview.includesHistory ? String(format: String(localized: "Clipboard history items: %d"), preview.historyCount) : String(localized: "Clipboard history: not included"))
        return lines.joined(separator: "\n")
    }
}

final class BackupPreferenceViewController: NSViewController {
    private let service: PreferencesBackupServicing?
    private let dialogProvider: PreferencesBackupDialogProviding
    private var sectionControls = [BackupPreferenceSection: NSButton]()

    init(
        service: PreferencesBackupServicing? = nil,
        dialogProvider: PreferencesBackupDialogProviding = AppKitPreferencesBackupDialogProvider()
    ) {
        self.service = service
        self.dialogProvider = dialogProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let view = makePreferencePane(height: 380)
        var y: CGFloat = 24

        addSectionLabel(String(localized: "Export Backup"), y: &y, to: view)
        addHelpLabel(
            String(localized: "Create a local backup file. ReClipt does not upload your data."),
            y: &y,
            to: view
        )
        addSectionCheckbox(.settings, title: String(localized: "Settings"), state: .on, y: &y, to: view)
        addSectionCheckbox(.snippets, title: String(localized: "Snippets"), state: .on, y: &y, to: view)
        addSectionCheckbox(.history, title: String(localized: "Clipboard history"), state: .off, y: &y, to: view)
        addHelpLabel(
            String(localized: "Clipboard history can contain private content. Include it only when needed."),
            y: &y,
            to: view
        )
        let exportButton = addActionButton(String(localized: "Export Backup…"), identifier: BackupPreferenceControlIdentifier.exportButton, action: #selector(exportBackup(_:)), y: &y, to: view)
        exportButton.keyEquivalent = ""

        y += 24
        addSectionLabel(String(localized: "Restore Backup"), y: &y, to: view)
        addHelpLabel(
            String(localized: "Choose a .recliptbackup file, review its contents, then select what to restore."),
            y: &y,
            to: view
        )
        addActionButton(String(localized: "Restore Backup…"), identifier: BackupPreferenceControlIdentifier.restoreButton, action: #selector(restoreBackup(_:)), y: &y, to: view)

        self.view = view
    }

    @objc private func exportBackup(_ sender: NSButton) {
        do {
            guard let service else { throw BackupPreferenceError.serviceUnavailable }
            let sections = selectedExportSections()
            guard !sections.isEmpty else { throw BackupPreferenceError.noExportSections }
            guard let url = dialogProvider.chooseExportURL(window: view.window) else { return }
            try service.exportBackup(to: url, sections: sections)
            dialogProvider.showSuccess(
                message: String(localized: "Backup exported"),
                informativeText: String(localized: "Your ReClipt backup was saved."),
                window: view.window
            )
        } catch {
            showFailure(error)
        }
    }

    @objc private func restoreBackup(_ sender: NSButton) {
        do {
            guard let service else { throw BackupPreferenceError.serviceUnavailable }
            guard let url = dialogProvider.chooseRestoreURL(window: view.window) else { return }
            let preview = try service.previewBackup(at: url)
            guard var sections = dialogProvider.chooseRestoreSections(for: preview, window: view.window) else { return }
            sections.formIntersection(preview.availableSections)
            guard !sections.isEmpty else { throw BackupPreferenceError.noRestoreSections }
            if sections.contains(.history), !dialogProvider.confirmRestoreClipboardHistory(window: view.window) {
                return
            }
            try service.restoreBackup(from: url, sections: sections)
            postRestoreNotifications(for: sections)
            dialogProvider.showSuccess(
                message: String(localized: "Backup restored"),
                informativeText: String(localized: "Your selected ReClipt data was restored."),
                window: view.window
            )
        } catch {
            showFailure(error)
        }
    }

    private func addSectionCheckbox(
        _ section: BackupPreferenceSection,
        title: String,
        state: NSControl.StateValue,
        y: inout CGFloat,
        to view: NSView
    ) {
        let checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        switch section {
        case .settings:
            checkbox.identifier = BackupPreferenceControlIdentifier.exportSettingsCheckbox
        case .snippets:
            checkbox.identifier = BackupPreferenceControlIdentifier.exportSnippetsCheckbox
        case .history:
            checkbox.identifier = BackupPreferenceControlIdentifier.exportHistoryCheckbox
        }
        checkbox.state = state
        checkbox.frame = NSRect(x: labelX, y: y, width: 360, height: 22)
        view.addSubview(checkbox)
        sectionControls[section] = checkbox
        y += 26
    }

    @discardableResult
    private func addActionButton(
        _ title: String,
        identifier: NSUserInterfaceItemIdentifier,
        action: Selector,
        y: inout CGFloat,
        to view: NSView
    ) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.identifier = identifier
        button.bezelStyle = .rounded
        button.frame = NSRect(x: labelX, y: y + 4, width: 160, height: 30)
        view.addSubview(button)
        y += 40
        return button
    }

    private func addHelpLabel(_ title: String, y: inout CGFloat, to view: NSView) {
        let label = NSTextField(wrappingLabelWithString: title)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: labelX, y: y, width: 470, height: 34)
        view.addSubview(label)
        y += 42
    }

    private func selectedExportSections() -> Set<BackupPreferenceSection> {
        Set(sectionControls.compactMap { section, checkbox in
            checkbox.state == .on ? section : nil
        })
    }

    private func postRestoreNotifications(for sections: Set<BackupPreferenceSection>) {
        if sections.contains(.settings) {
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: AppEnvironment.current.defaults)
        }
        if sections.contains(.snippets) {
            NotificationCenter.default.post(name: SnippetRepository.snippetsDidChangeNotification, object: nil)
        }
        if sections.contains(.history) {
            NotificationCenter.default.post(name: PasteboardHistoryRepository.historyDidChangeNotification, object: nil)
        }
    }

    private func showFailure(_ error: Error) {
        let message = String(localized: "Backup failed")
        let informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        dialogProvider.showFailure(message: message, informativeText: informativeText, window: view.window)
    }
}

private extension NSViewController {
    var labelX: CGFloat { 64 }
    var fieldX: CGFloat { 322 }
    var paneWidth: CGFloat { 640 }

    func makePreferencePane(width: CGFloat? = nil, height: CGFloat) -> FlippedPreferenceView {
        let view = FlippedPreferenceView(frame: NSRect(x: 0, y: 0, width: width ?? paneWidth, height: height))
        view.autoresizingMask = [.width, .height]
        return view
    }

    func addSectionLabel(_ title: String, y: inout CGFloat, to view: NSView, x: CGFloat? = nil, width: CGFloat = 360) {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: x ?? labelX, y: y, width: width, height: 18)
        view.addSubview(label)
        y += 27
    }

    func addCheckbox(_ title: String, key: String, y: inout CGFloat, to view: NSView, truthyNonBool: Bool = false, x: CGFloat? = nil, width: CGFloat = 390) {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(handleCheckboxToggle(_:)))
        checkbox.identifier = NSUserInterfaceItemIdentifier(rawValue: key + (truthyNonBool ? "::truthy" : ""))
        checkbox.state = checkboxState(forKey: key, truthyNonBool: truthyNonBool)
        checkbox.frame = NSRect(x: x ?? labelX, y: y, width: width, height: 22)
        view.addSubview(checkbox)
        y += 26
    }

    func addNumberRow(
        _ title: String,
        key: String,
        range: ClosedRange<Int>,
        unit: String,
        y: inout CGFloat,
        to view: NSView,
        x: CGFloat? = nil,
        fieldX: CGFloat? = nil,
        labelWidth: CGFloat = 240
    ) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: x ?? labelX, y: y + 3, width: labelWidth, height: 20)
        view.addSubview(label)

        let field = makeNumberField(key: key, range: range)
        field.frame = NSRect(x: fieldX ?? self.fieldX, y: y, width: 64, height: 24)
        view.addSubview(field)

        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.frame = NSRect(x: field.frame.maxX + 8, y: y + 3, width: 80, height: 20)
        view.addSubview(unitLabel)

        y += 30
    }

    func addNumberPairRow(
        _ title: String,
        firstKey: String,
        firstUnit: String,
        secondKey: String,
        secondUnit: String,
        range: ClosedRange<Int>,
        y: inout CGFloat,
        to view: NSView,
        x: CGFloat? = nil,
        fieldX: CGFloat? = nil,
        labelWidth: CGFloat = 240
    ) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: x ?? labelX, y: y + 3, width: labelWidth, height: 20)
        view.addSubview(label)

        let firstField = makeNumberField(key: firstKey, range: range)
        firstField.frame = NSRect(x: fieldX ?? self.fieldX, y: y, width: 56, height: 24)
        view.addSubview(firstField)

        let firstUnitLabel = NSTextField(labelWithString: firstUnit)
        firstUnitLabel.textColor = .secondaryLabelColor
        firstUnitLabel.frame = NSRect(x: firstField.frame.maxX + 6, y: y + 3, width: 20, height: 20)
        view.addSubview(firstUnitLabel)

        let secondField = makeNumberField(key: secondKey, range: range)
        secondField.frame = NSRect(x: firstUnitLabel.frame.maxX + 16, y: y, width: 56, height: 24)
        view.addSubview(secondField)

        let secondUnitLabel = NSTextField(labelWithString: secondUnit)
        secondUnitLabel.textColor = .secondaryLabelColor
        secondUnitLabel.frame = NSRect(x: secondField.frame.maxX + 6, y: y + 3, width: 20, height: 20)
        view.addSubview(secondUnitLabel)

        y += 30
    }

    func addPopupRow(
        _ title: String,
        key: String,
        options: [(title: String, tag: Int)],
        y: inout CGFloat,
        to view: NSView
    ) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: labelX, y: y + 4, width: 240, height: 20)
        view.addSubview(label)

        let popup = NSPopUpButton(frame: NSRect(x: fieldX, y: y, width: 150, height: 26), pullsDown: false)
        options.forEach { option in
            popup.addItem(withTitle: option.title)
            popup.lastItem?.tag = option.tag
        }
        popup.identifier = NSUserInterfaceItemIdentifier(rawValue: key)
        popup.target = self
        popup.action = #selector(handlePopupSelection(_:))
        popup.selectItem(withTag: AppEnvironment.current.defaults.integer(forKey: key))
        view.addSubview(popup)

        y += 32
    }

    func makeNumberField(key: String, range: ClosedRange<Int>) -> NSTextField {
        let field = NSTextField()
        field.alignment = .right
        field.identifier = NSUserInterfaceItemIdentifier(rawValue: key)
        field.target = self
        field.action = #selector(handleNumberFieldChange(_:))
        field.cell?.sendsActionOnEndEditing = true
        field.integerValue = AppEnvironment.current.defaults.integer(forKey: key)

        let formatter = NumberFormatter()
        formatter.minimum = NSNumber(value: range.lowerBound)
        formatter.maximum = NSNumber(value: range.upperBound)
        formatter.allowsFloats = false
        formatter.numberStyle = .none
        field.formatter = formatter

        return field
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
