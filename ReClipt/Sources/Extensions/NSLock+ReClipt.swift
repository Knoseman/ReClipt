//
//  NSLock+ReClipt.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

extension NSRecursiveLock {
    convenience init(name: String) {
        self.init()
        self.name = name
    }
}
