//
//  NSBundle+Version.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/03/29.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Foundation

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
