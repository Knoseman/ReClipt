//
//  TypePreferenceViewController.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

final class TypePreferenceViewController: NSViewController {
    // MARK: - Properties
    @objc var storeTypes: NSMutableDictionary!

    // MARK: - Initialize
    override func loadView() {
        let view = TypePreferencePaneView(frame: NSRect(x: 0, y: 0, width: 520, height: 310))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Clipboard Types"))
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 64, y: 24, width: 250, height: 18)
        view.addSubview(label)

        let helpLabel = NSTextField(labelWithString: String(localized: "Choose which clipboard formats ReClipt stores in history."))
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.frame = NSRect(x: 64, y: 50, width: 390, height: 20)
        view.addSubview(helpLabel)

        if let dictionary = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: Any] {
            storeTypes = NSMutableDictionary(dictionary: dictionary)
        } else {
            storeTypes = NSMutableDictionary()
        }

        var yOffset: CGFloat = 86
        PasteboardAvailableType.allCases.forEach { availableType in
            let checkbox = NSButton(checkboxWithTitle: availableType.rawValue, target: self, action: #selector(typeCheckboxChanged(_:)))
            checkbox.state = (storeTypes[availableType.rawValue] as? Bool ?? true) ? .on : .off
            checkbox.tag = PasteboardAvailableType.allCases.firstIndex(of: availableType) ?? 0
            checkbox.frame = NSRect(x: 64, y: yOffset, width: 200, height: 24)
            view.addSubview(checkbox)
            yOffset += 28
        }
    }

    @objc private func typeCheckboxChanged(_ sender: NSButton) {
        let type = PasteboardAvailableType.allCases[sender.tag]
        storeTypes[type.rawValue] = (sender.state == .on)
        AppEnvironment.current.defaults.set(storeTypes, forKey: Constants.UserDefaults.storeTypes)
        AppEnvironment.current.defaults.synchronize()
        AppEnvironment.current.clipService.reloadStoreTypes()
    }
}

private final class TypePreferencePaneView: NSView {
    override var isFlipped: Bool { true }
}
