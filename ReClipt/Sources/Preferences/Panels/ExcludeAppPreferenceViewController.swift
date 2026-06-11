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
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Excluded Applications"))
        label.font = NSFont.boldSystemFont(ofSize: 16)
        label.frame = NSRect(x: 20, y: 300, width: 250, height: 24)
        view.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: 460, height: 230))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("appName")))
        tableView.headerView = nil
        tableView.dataSource = self
        scrollView.documentView = tableView
        view.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 20, y: 20, width: 80, height: 28))
        addButton.title = String(localized: "Add")
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addAppButtonTapped(_:))
        view.addSubview(addButton)

        let deleteButton = NSButton(frame: NSRect(x: 110, y: 20, width: 80, height: 28))
        deleteButton.title = String(localized: "Delete")
        deleteButton.bezelStyle = .rounded
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
