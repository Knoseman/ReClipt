//
//  DesignableButton.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

class DesignableButton: NSButton {

    @IBInspectable var textColor: NSColor = NSColor(named: "title") ?? .labelColor

    // MARK: - Initialize
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
    }

    private func initView() {
        let attributedString = NSAttributedString(string: title, attributes: [.foregroundColor: textColor])
        attributedTitle = attributedString
    }
}
