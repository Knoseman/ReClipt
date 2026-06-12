//
//  ShortcutsPreferenceViewController.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

class ShortcutsPreferenceViewController: NSViewController {

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
        let view = ShortcutsPreferencePaneView(frame: NSRect(x: 0, y: 0, width: 520, height: 330))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Menu"))
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 64, y: 24, width: 250, height: 18)
        view.addSubview(label)

        var yOffset: CGFloat = 64
        mainShortcutRecordView = addShortcutRow(
            title: String(localized: "Main Menu:"),
            keyCombo: AppEnvironment.current.hotKeyService.mainKeyCombo,
            target: .main,
            yOffset: yOffset,
            to: view
        )
        yOffset += 48

        historyShortcutRecordView = addShortcutRow(
            title: String(localized: "History Menu:"),
            keyCombo: AppEnvironment.current.hotKeyService.historyKeyCombo,
            target: .history,
            yOffset: yOffset,
            to: view
        )
        yOffset += 48

        snippetShortcutRecordView = addShortcutRow(
            title: String(localized: "Snippet Menu:"),
            keyCombo: AppEnvironment.current.hotKeyService.snippetKeyCombo,
            target: .snippet,
            yOffset: yOffset,
            to: view
        )
        yOffset += 58

        let historyLabel = NSTextField(labelWithString: String(localized: "History"))
        historyLabel.font = NSFont.boldSystemFont(ofSize: 13)
        historyLabel.textColor = .secondaryLabelColor
        historyLabel.frame = NSRect(x: 64, y: yOffset, width: 250, height: 18)
        view.addSubview(historyLabel)
        yOffset += 40

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
        titleLabel.frame = NSRect(x: 64, y: yOffset + 4, width: 130, height: 24)
        view.addSubview(titleLabel)

        let recorder = HotKeyRecorderView(frame: NSRect(x: 200, y: yOffset, width: 240, height: 30))
        recorder.keyCombo = keyCombo
        recorder.delegate = self
        shortcutTargets[ObjectIdentifier(recorder)] = target
        view.addSubview(recorder)
        return recorder
    }
}

// MARK: - HotKeyRecorderView Delegate
extension ShortcutsPreferenceViewController: HotKeyRecorderViewDelegate {
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

private final class ShortcutsPreferencePaneView: NSView {
    override var isFlipped: Bool { true }
}
