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
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        self.view = view

        let label = NSTextField(labelWithString: String(localized: "Store Types"))
        label.font = NSFont.boldSystemFont(ofSize: 16)
        label.frame = NSRect(x: 20, y: 300, width: 250, height: 24)
        view.addSubview(label)

        if let dictionary = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: Any] {
            storeTypes = NSMutableDictionary(dictionary: dictionary)
        } else {
            storeTypes = NSMutableDictionary()
        }

        var yOffset: CGFloat = 260
        PasteboardAvailableType.allCases.forEach { availableType in
            let checkbox = NSButton(checkboxWithTitle: availableType.rawValue, target: self, action: #selector(typeCheckboxChanged(_:)))
            checkbox.state = (storeTypes[availableType.rawValue] as? Bool ?? true) ? .on : .off
            checkbox.tag = PasteboardAvailableType.allCases.firstIndex(of: availableType) ?? 0
            checkbox.frame = NSRect(x: 20, y: yOffset, width: 200, height: 24)
            view.addSubview(checkbox)
            yOffset -= 30
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
