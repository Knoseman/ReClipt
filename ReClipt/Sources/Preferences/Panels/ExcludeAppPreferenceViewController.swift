//
//  ExcludeAppPreferenceViewController.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

class ExcludeAppPreferenceViewController: NSViewController {
    // MARK: - Properties
    private var tableView: NSTableView!

    override func loadView() {
        let view = ExcludePreferencePaneView(frame: NSRect(x: 0, y: 0, width: 520, height: 350))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Excluded Applications"))
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 64, y: 24, width: 250, height: 18)
        view.addSubview(label)

        let helpLabel = NSTextField(labelWithString: String(localized: "Clipboard changes from these apps will not be stored."))
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.frame = NSRect(x: 64, y: 50, width: 390, height: 20)
        view.addSubview(helpLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 64, y: 86, width: 392, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("appName"))
        column.width = 392
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        scrollView.documentView = tableView
        view.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 64, y: 296, width: 28, height: 24))
        addButton.title = "+"
        addButton.bezelStyle = .smallSquare
        addButton.target = self
        addButton.action = #selector(addAppButtonTapped(_:))
        view.addSubview(addButton)

        let deleteButton = NSButton(frame: NSRect(x: 91, y: 296, width: 28, height: 24))
        deleteButton.title = "-"
        deleteButton.bezelStyle = .smallSquare
        deleteButton.target = self
        deleteButton.action = #selector(deleteAppButtonTapped(_:))
        view.addSubview(deleteButton)
    }

    @objc private func addAppButtonTapped(_ sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["app"]
        openPanel.allowsMultipleSelection = true
        openPanel.resolvesAliases = true
        openPanel.prompt = String(localized: "Add")
        let directories = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true)
        let basePath = (directories.isEmpty) ? NSHomeDirectory() : directories.first!
        openPanel.directoryURL = URL(fileURLWithPath: basePath)

        let returnCode = openPanel.runModal()
        if returnCode != NSApplication.ModalResponse.OK { return }

        let fileURLs = openPanel.urls
        fileURLs.forEach {
            guard let bundle = Bundle(url: $0), let info = bundle.infoDictionary else { return }
            guard let appInfo = ReCliptAppInfo(info: info as [String: AnyObject]) else { return }
            AppEnvironment.current.excludeAppService.add(with: appInfo)
        }
        tableView.reloadData()
    }

    @objc private func deleteAppButtonTapped(_ sender: AnyObject) {
        let index = tableView.selectedRow
        if index == -1 {
            NSSound.beep()
            return
        }
        AppEnvironment.current.excludeAppService.delete(with: index)
        tableView.reloadData()
    }
}

extension ExcludeAppPreferenceViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return AppEnvironment.current.excludeAppService.applications.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return AppEnvironment.current.excludeAppService.applications[safe: row]?.name
    }
}

private final class ExcludePreferencePaneView: NSView {
    override var isFlipped: Bool { true }
}
