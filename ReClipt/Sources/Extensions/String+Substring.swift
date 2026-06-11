//
//  String+Substring.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/03/17.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Foundation

extension String {
    subscript (range: CountableClosedRange<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound, limitedBy: self.endIndex) ?? self.startIndex
        let endIndex = self.index(self.startIndex, offsetBy: range.upperBound, limitedBy: self.endIndex) ?? self.endIndex

        return String(self[startIndex..<endIndex])
    }
}
