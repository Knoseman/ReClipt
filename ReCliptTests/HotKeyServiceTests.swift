//
//  HotKeyServiceTests.swift
//
//  ReClipt
//
//  Created by Econa77 on 2016/11/19.
//
//  Copyright © 2015-2018 ReClipt Project.
//

import Carbon
import Foundation
import Testing
@testable import ReClipt

@Suite(.serialized)
final class HotKeyServiceTests {
    init() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
        defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.clearHistoryKeyCombo)
        defaults.synchronize()
    }

    deinit {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
        defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.clearHistoryKeyCombo)
        defaults.synchronize()
    }

    @Test
    func migrateDefaultSettings() throws {
        let service = HotKeyService()
        #expect(service.mainKeyCombo == nil)
        #expect(service.historyKeyCombo == nil)
        #expect(service.snippetKeyCombo == nil)

        let defaults = UserDefaults.standard
        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) == false)
        service.setupDefaultHotKeys()
        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) == true)
    }

    @Test
    func keyComboCreation() throws {
        let keyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
        #expect(keyCombo.QWERTYKeyCode == 9)
        #expect(keyCombo.modifiers == 768)
    }

    @Test
    func keyComboArchiving() throws {
        let keyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
        let data = keyCombo.archive()
        let unarchived = try #require(NSKeyedUnarchiver.unarchiveObject(with: data) as? KeyCombo)
        #expect(unarchived.QWERTYKeyCode == keyCombo.QWERTYKeyCode)
        #expect(unarchived.modifiers == keyCombo.modifiers)
    }
}
