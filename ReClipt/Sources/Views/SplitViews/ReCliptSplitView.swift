//
//  ReCliptSplitView.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

class ReCliptSplitView: NSSplitView {

    // MARK: - Properties
    @IBInspectable var separatorColor: NSColor = .scrollBarColor {
        didSet {
            needsDisplay = true
        }
    }

    // MARK: - Draw
    override func drawDivider(in rect: NSRect) {
        separatorColor.setFill()
        rect.fill()
    }

}
