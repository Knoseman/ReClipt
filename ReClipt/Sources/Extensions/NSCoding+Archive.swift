//
//  NSCoding+Archive.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

extension NSCoding {
    func archive() -> Data {
        (try? NSKeyedArchiver.archivedData(
            withRootObject: self,
            requiringSecureCoding: self is NSSecureCoding
        )) ?? Data()
    }
}

extension Array where Element: NSCoding {
    func archive() -> Data {
        (try? NSKeyedArchiver.archivedData(
            withRootObject: self,
            requiringSecureCoding: allSatisfy { $0 is NSSecureCoding }
        )) ?? Data()
    }
}
