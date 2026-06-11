//
//  Collection+Safe.swift
//
//  ReClipt
//
//  Created by Econa77 on 2017/03/01.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}
