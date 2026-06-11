//
//  NSImage+NSColor.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/11/21.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Cocoa

extension NSImage {
    static func create(with color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        image.unlockFocus()
        return image
    }
}
