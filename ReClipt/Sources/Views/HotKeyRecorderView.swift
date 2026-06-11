//
//  HotKeyRecorderView.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Cocoa
import Carbon

protocol HotKeyRecorderViewDelegate: AnyObject {
    func hotKeyRecorderView(_ view: HotKeyRecorderView, didChangeKeyCombo keyCombo: KeyCombo?)
}

final class HotKeyRecorderView: NSView {

    weak var delegate: HotKeyRecorderViewDelegate?

    var keyCombo: KeyCombo? {
        didSet {
            updateDisplay()
            delegate?.hotKeyRecorderView(self, didChangeKeyCombo: keyCombo)
        }
    }

    private var isRecording = false
    private let textField: NSTextField

    override init(frame frameRect: NSRect) {
        textField = NSTextField(frame: NSRect(x: 5, y: 5, width: frameRect.width - 10, height: frameRect.height - 10))
        textField.isEditable = false
        textField.isSelectable = false
        textField.alignment = .center
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.backgroundColor = .clear
        textField.isBordered = false
        super.init(frame: frameRect)
        addSubview(textField)
        updateDisplay()
        setupTracking()
    }

    required init?(coder: NSCoder) {
        textField = NSTextField(frame: .zero)
        super.init(coder: coder)
        addSubview(textField)
        updateDisplay()
        setupTracking()
    }

    private func setupTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
        if isRecording {
            NSColor.selectedControlColor.setStroke()
            path.lineWidth = 2
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
        }
        path.stroke()

        NSColor.controlBackgroundColor.setFill()
        path.fill()
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = Int(event.keyCode)
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // Require at least one modifier
        guard !modifiers.isEmpty else {
            if event.keyCode == 53 { // Escape
                stopRecording()
            }
            return
        }

        // Ignore modifier-only presses
        guard !isModifierKey(keyCode) else { return }

        keyCombo = KeyCombo(keyCode: keyCode, cocoaModifiers: modifiers)
        stopRecording()
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle modifier-only changes during recording
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        startRecording()
        return true
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return true
    }

    // MARK: - Private

    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        updateDisplay()
        needsDisplay = true
    }

    private func stopRecording() {
        isRecording = false
        updateDisplay()
        needsDisplay = true
    }

    private func updateDisplay() {
        if isRecording {
            textField.stringValue = String(localized: "Press shortcut...")
            textField.textColor = .secondaryLabelColor
        } else if let keyCombo = keyCombo {
            textField.stringValue = keyCombo.displayString
            textField.textColor = .labelColor
        } else {
            textField.stringValue = String(localized: "Click to record")
            textField.textColor = .secondaryLabelColor
        }
    }

    private func isModifierKey(_ keyCode: Int) -> Bool {
        // Key codes for modifier keys
        let modifierKeys: [Int] = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63] // cmd, shift, option, control variants
        return modifierKeys.contains(keyCode)
    }
}

// MARK: - KeyCombo Description

extension KeyCombo {
    var displayString: String {
        var parts = [String]()
        if modifiers & Int(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & Int(optionKey) != 0 { parts.append("⌥") }
        if modifiers & Int(controlKey) != 0 { parts.append("⌃") }
        if modifiers & Int(shiftKey) != 0 { parts.append("⇧") }
        parts.append(keyCodeToString(QWERTYKeyCode))
        return parts.joined(separator: "+")
    }

    private func keyCodeToString(_ keyCode: Int) -> String {
        // Common key codes
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Esc", 55: "Cmd", 56: "Shift",
            57: "Caps", 58: "Option", 59: "Ctrl", 123: "←", 124: "→",
            125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "Key \(keyCode)"
    }
}
