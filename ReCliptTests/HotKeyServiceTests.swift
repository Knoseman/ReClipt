//
//  HotKeyServiceTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
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
    func migratesLegacyHotKeyDictionaryIntoArchivedKeyCombos() throws {
        let suiteName = "MigratesLegacyHotKeyDictionaryIntoArchivedKeyCombos"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set([
            Constants.Menu.clip: ["keyCode": 10, "modifiers": 768],
            Constants.Menu.history: ["keyCode": 11, "modifiers": 4352],
            Constants.Menu.snippet: ["keyCode": 12, "modifiers": 512]
        ], forKey: Constants.UserDefaults.hotKeys)

        AppEnvironment.push(defaults: defaults)
        defer { _ = AppEnvironment.popLast() }

        HotKeyService().setupDefaultHotKeys()

        #expect(try archivedKeyCombo(defaults, Constants.HotKey.mainKeyCombo)?.QWERTYKeyCode == 10)
        #expect(try archivedKeyCombo(defaults, Constants.HotKey.mainKeyCombo)?.modifiers == 768)
        #expect(try archivedKeyCombo(defaults, Constants.HotKey.historyKeyCombo)?.QWERTYKeyCode == 11)
        #expect(try archivedKeyCombo(defaults, Constants.HotKey.historyKeyCombo)?.modifiers == 4352)
        #expect(try archivedKeyCombo(defaults, Constants.HotKey.snippetKeyCombo)?.QWERTYKeyCode == 12)
        #expect(try archivedKeyCombo(defaults, Constants.HotKey.snippetKeyCombo)?.modifiers == 512)
        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo))
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
        let unarchived = try #require(try NSKeyedUnarchiver.unarchivedObject(ofClass: KeyCombo.self, from: data))
        #expect(unarchived.QWERTYKeyCode == keyCombo.QWERTYKeyCode)
        #expect(unarchived.modifiers == keyCombo.modifiers)
    }

    private func archivedKeyCombo(_ defaults: UserDefaults, _ key: String) throws -> KeyCombo? {
        guard let data = defaults.object(forKey: key) as? Data else { return nil }
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: KeyCombo.self, from: data)
    }
}
