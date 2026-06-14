//
//  ReCliptAppInfo.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa

final class ReCliptAppInfo: NSObject, NSSecureCoding {
    static let supportsSecureCoding = true

    // MARK: - Properties
    let identifier: String
    let name: String

    // MARK: - Initialize
    init?(info: [String: AnyObject]) {
        guard let identifier = info[kCFBundleIdentifierKey as String] as? String else { return nil }
        guard let name = info[kCFBundleNameKey as String] as? String ?? info[kCFBundleExecutableKey as String] as? String else { return nil }

        self.identifier = identifier
        self.name = name
    }

    // MARK: - NSCoding
    init?(coder aDecoder: NSCoder) {
        guard let identifier = aDecoder.decodeObject(of: NSString.self, forKey: "identifier") as? String else { return nil }
        guard let name = aDecoder.decodeObject(of: NSString.self, forKey: "name") as? String else { return nil }

        self.identifier = identifier
        self.name = name
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(identifier, forKey: "identifier")
        aCoder.encode(name, forKey: "name")
    }

    // MARK: - Equatable
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ReCliptAppInfo else { return false }
        return identifier == object.identifier && name == object.name
    }

}
