//
//  NSLock+ReClipt.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/01/20.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Foundation

extension NSRecursiveLock {
    convenience init(name: String) {
        self.init()
        self.name = name
    }
}
