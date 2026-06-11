//
//  String+Substring.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

extension String {
    subscript (range: CountableClosedRange<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound, limitedBy: self.endIndex) ?? self.startIndex
        let endIndex = self.index(self.startIndex, offsetBy: range.upperBound, limitedBy: self.endIndex) ?? self.endIndex

        return String(self[startIndex..<endIndex])
    }
}
