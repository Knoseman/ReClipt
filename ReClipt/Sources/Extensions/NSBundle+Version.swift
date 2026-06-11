//
//  NSBundle+Version.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
