//
//  NSMenuItem+Initialize.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation
import Cocoa

extension NSMenuItem {
    convenience init(title: String, action: Selector?) {
        self.init(title: title, action: action, keyEquivalent: "")
    }
}
