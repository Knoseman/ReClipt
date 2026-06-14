//
//  MenuType.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

enum MenuType: String {
    case main       = "ReCliptMenu"
    case history    = "HistoryMenu"
    case snippet    = "SnippetsMenu"

    var userDefaultsKey: String {
        switch self {
        case .main:
            return Constants.HotKey.mainKeyCombo
        case .history:
            return Constants.HotKey.historyKeyCombo
        case .snippet:
            return Constants.HotKey.snippetKeyCombo
        }
    }

    var hotKeySelector: Selector {
        switch self {
        case .main:
            return #selector(HotKeyService.popupMainMenu)
        case .history:
            return #selector(HotKeyService.popupHistoryMenu)
        case .snippet:
            return #selector(HotKeyService.popUpSnippetMenu)
        }
    }

}
