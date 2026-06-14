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
        guard !isEmpty else { return "" }

        let lowerBound = max(0, range.lowerBound)
        let upperBound = min(count - 1, range.upperBound)
        guard lowerBound <= upperBound else { return "" }

        let startIndex = index(self.startIndex, offsetBy: lowerBound)
        let endIndex = index(self.startIndex, offsetBy: upperBound)
        return String(self[startIndex...endIndex])
    }
}
