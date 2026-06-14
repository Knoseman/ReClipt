//
//  MenuTypeTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/14.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation
import Testing
@testable import ReClipt

@Suite
struct MenuTypeTests {
    @Test
    func rawValuesMatchHotKeyIdentifiers() {
        #expect(MenuType.main.rawValue == Constants.Menu.clip)
        #expect(MenuType.history.rawValue == Constants.Menu.history)
        #expect(MenuType.snippet.rawValue == Constants.Menu.snippet)
    }

    @Test
    func userDefaultsKeysMatchHotKeyStorageKeys() {
        #expect(MenuType.main.userDefaultsKey == Constants.HotKey.mainKeyCombo)
        #expect(MenuType.history.userDefaultsKey == Constants.HotKey.historyKeyCombo)
        #expect(MenuType.snippet.userDefaultsKey == Constants.HotKey.snippetKeyCombo)
    }

    @Test
    func hotKeySelectorsPointToExpectedServiceActions() {
        #expect(MenuType.main.hotKeySelector == #selector(HotKeyService.popupMainMenu))
        #expect(MenuType.history.hotKeySelector == #selector(HotKeyService.popupHistoryMenu))
        #expect(MenuType.snippet.hotKeySelector == #selector(HotKeyService.popUpSnippetMenu))
    }
}
