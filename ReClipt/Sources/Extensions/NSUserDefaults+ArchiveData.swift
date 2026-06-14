//
//  NSUserDefaults+ArchiveData.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation
import Cocoa

extension UserDefaults {
    func setArchiveData<T: NSCoding>(_ object: T, forKey key: String) {
        let data = (try? NSKeyedArchiver.archivedData(
            withRootObject: object,
            requiringSecureCoding: object is NSSecureCoding
        )) ?? Data()
        set(data, forKey: key)
    }

    func archiveDataForKey<T: NSCoding>(_: T.Type, key: String) -> T? {
        guard let data = object(forKey: key) as? Data else { return nil }
        var classes: [AnyClass] = [NSArray.self, NSDictionary.self, NSString.self, NSNumber.self, NSData.self]
        classes.append(T.self as AnyClass)
        return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? T
    }
}
