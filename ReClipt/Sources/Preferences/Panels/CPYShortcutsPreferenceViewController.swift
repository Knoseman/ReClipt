//
//  CPYShortcutsPreferenceViewController.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/02/26.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Cocoa

class CPYShortcutsPreferenceViewController: NSViewController {

    // MARK: - Properties
    private enum ShortcutTarget {
        case main
        case history
        case snippet
        case clearHistory
    }

    private var mainShortcutRecordView: HotKeyRecorderView!
    private var historyShortcutRecordView: HotKeyRecorderView!
    private var snippetShortcutRecordView: HotKeyRecorderView!
    private var clearHistoryShortcutRecordView: HotKeyRecorderView!
    private var shortcutTargets = [ObjectIdentifier: ShortcutTarget]()

    // MARK: - Initialize
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Keyboard Shortcuts"))
        label.font = NSFont.boldSystemFont(ofSize: 16)
        label.frame = NSRect(x: 20, y: 300, width: 250, height: 24)
        view.addSubview(label)

        var yOffset: CGFloat = 260
        mainShortcutRecordView = addShortcutRow(
            title: String(localized: "Main Menu:"),
            keyCombo: AppEnvironment.current.hotKeyService.mainKeyCombo,
            target: .main,
            yOffset: yOffset,
            to: view
        )
        yOffset -= 50

        historyShortcutRecordView = addShortcutRow(
            title: String(localized: "History Menu:"),
            keyCombo: AppEnvironment.current.hotKeyService.historyKeyCombo,
            target: .history,
            yOffset: yOffset,
            to: view
        )
        yOffset -= 50

        snippetShortcutRecordView = addShortcutRow(
            title: String(localized: "Snippet Menu:"),
            keyCombo: AppEnvironment.current.hotKeyService.snippetKeyCombo,
            target: .snippet,
            yOffset: yOffset,
            to: view
        )
        yOffset -= 50

        clearHistoryShortcutRecordView = addShortcutRow(
            title: String(localized: "Clear History:"),
            keyCombo: AppEnvironment.current.hotKeyService.clearHistoryKeyCombo,
            target: .clearHistory,
            yOffset: yOffset,
            to: view
        )
    }

    private func addShortcutRow(
        title: String,
        keyCombo: KeyCombo?,
        target: ShortcutTarget,
        yOffset: CGFloat,
        to view: NSView
    ) -> HotKeyRecorderView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: 20, y: yOffset, width: 150, height: 24)
        view.addSubview(titleLabel)

        let recorder = HotKeyRecorderView(frame: NSRect(x: 180, y: yOffset, width: 200, height: 30))
        recorder.keyCombo = keyCombo
        recorder.delegate = self
        shortcutTargets[ObjectIdentifier(recorder)] = target
        view.addSubview(recorder)
        return recorder
    }
}

// MARK: - HotKeyRecorderView Delegate
extension CPYShortcutsPreferenceViewController: HotKeyRecorderViewDelegate {
    func hotKeyRecorderView(_ view: HotKeyRecorderView, didChangeKeyCombo keyCombo: KeyCombo?) {
        guard let target = shortcutTargets[ObjectIdentifier(view)] else { return }
        switch target {
        case .main:
            AppEnvironment.current.hotKeyService.change(with: .main, keyCombo: keyCombo)
        case .history:
            AppEnvironment.current.hotKeyService.change(with: .history, keyCombo: keyCombo)
        case .snippet:
            AppEnvironment.current.hotKeyService.change(with: .snippet, keyCombo: keyCombo)
        case .clearHistory:
            AppEnvironment.current.hotKeyService.changeClearHistoryKeyCombo(keyCombo)
        }
    }
}
