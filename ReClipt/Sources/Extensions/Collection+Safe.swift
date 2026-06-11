//
//  Collection+Safe.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}
