//
//  MenuType.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/06/26.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Foundation

enum MenuType: String {
    case main       = "ReCliptMenu"
    case history    = "HistoryMenu"
    case snippet    = "SnippetMenu"

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
