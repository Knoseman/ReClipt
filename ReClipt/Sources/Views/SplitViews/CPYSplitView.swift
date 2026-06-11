//
//  CPYSplitView.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/06/29.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Cocoa

class CPYSplitView: NSSplitView {

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
