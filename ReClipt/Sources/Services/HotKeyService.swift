//
//  HotKeyService.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa
import Foundation
import Carbon

final class HotKeyService: NSObject {
    // MARK: - Properties
    static var defaultKeyCombos: [String: Any] = {
        // MainMenu:    ⌘ + Shift + V
        // HistoryMenu: ⌘ + Control + V
        // SnipeetMenu: ⌘ + Shift B
        return [Constants.Menu.clip: ["keyCode": 9, "modifiers": 768],
                Constants.Menu.history: ["keyCode": 9, "modifiers": 4352],
                Constants.Menu.snippet: ["keyCode": 11, "modifiers": 768]]
    }()

    fileprivate(set) var mainKeyCombo: KeyCombo?
    fileprivate(set) var historyKeyCombo: KeyCombo?
    fileprivate(set) var snippetKeyCombo: KeyCombo?
    fileprivate(set) var clearHistoryKeyCombo: KeyCombo?

    private let snippetRepository = SnippetRepository()
    private var hotKeys = [String: EventHotKeyRef]()
    private var hotKeyIDsByIdentifier = [String: UInt32]()
    private var hotKeyIdentifiersByID = [UInt32: String]()
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    // MARK: - Init
    override init() {
        super.init()
        setupCarbonEventHandler()
    }

    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    // MARK: - Actions
    @objc func popupMainMenu() {
        AppEnvironment.current.menuManager.popUpMenu(.main)
    }

    @objc func popupHistoryMenu() {
        AppEnvironment.current.menuManager.popUpMenu(.history)
    }

    @objc func popUpSnippetMenu() {
        AppEnvironment.current.menuManager.popUpMenu(.snippet)
    }

    @objc func popUpClearHistoryAlert() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.clearAllHistory()
    }

    // MARK: - Setup
    func setupDefaultHotKeys() {
        // Migration new framework
        if !AppEnvironment.current.defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) {
            migrationKeyCombos()
            AppEnvironment.current.defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
            AppEnvironment.current.defaults.synchronize()
        }
        // Snippet hotkey
        setupSnippetHotKeys()

        // Main menu
        change(with: .main, keyCombo: savedKeyCombo(forKey: Constants.HotKey.mainKeyCombo))
        // History menu
        change(with: .history, keyCombo: savedKeyCombo(forKey: Constants.HotKey.historyKeyCombo))
        // Snippet menu
        change(with: .snippet, keyCombo: savedKeyCombo(forKey: Constants.HotKey.snippetKeyCombo))
        // Clear History
        changeClearHistoryKeyCombo(savedKeyCombo(forKey: Constants.HotKey.clearHistoryKeyCombo))
    }

    func change(with type: MenuType, keyCombo: KeyCombo?) {
        switch type {
        case .main:
            mainKeyCombo = keyCombo
        case .history:
            historyKeyCombo = keyCombo
        case .snippet:
            snippetKeyCombo = keyCombo
        }
        register(with: type, keyCombo: keyCombo)
    }

    func changeClearHistoryKeyCombo(_ keyCombo: KeyCombo?) {
        clearHistoryKeyCombo = keyCombo
        AppEnvironment.current.defaults.set(keyCombo?.archive(), forKey: Constants.HotKey.clearHistoryKeyCombo)
        AppEnvironment.current.defaults.synchronize()
        // Reset hotkey
        unregisterHotKey(with: "ClearHistory")
        // Register new hotkey
        guard let keyCombo = keyCombo else { return }
        registerCarbonHotKey(identifier: "ClearHistory", keyCode: keyCode(keyCombo), modifiers: carbonModifiers(keyCombo), action: #selector(HotKeyService.popUpClearHistoryAlert))
    }

    private func savedKeyCombo(forKey key: String) -> KeyCombo? {
        guard let data = AppEnvironment.current.defaults.object(forKey: key) as? Data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: KeyCombo.self, from: data)
    }
}

// MARK: - Carbon HotKey Registration
private extension HotKeyService {
    func setupCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, eventRef, userData -> OSStatus in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard let service = Unmanaged<HotKeyService>.fromOpaque(userData!).takeUnretainedValue() as HotKeyService? else {
                return OSStatus(eventNotHandledErr)
            }
            service.handleHotKeyPressed(id: hotKeyID.id)
            return noErr
        }
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventType, userData, &eventHandler)
    }

    func handleHotKeyPressed(id: UInt32) {
        guard let identifier = hotKeyIdentifiersByID[id] else { return }
        switch identifier {
        case Constants.Menu.clip:
            popupMainMenu()
        case Constants.Menu.history:
            popupHistoryMenu()
        case Constants.Menu.snippet:
            popUpSnippetMenu()
        case "ClearHistory":
            popUpClearHistoryAlert()
        default:
            if let folderID = UUID(uuidString: identifier) {
                popupSnippetFolder(folderID: folderID)
            }
        }
    }

    func registerCarbonHotKey(identifier: String, keyCode: UInt32, modifiers: UInt32, action: Selector) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x52434C50 // RCLP
        hotKeyID.id = nextHotKeyID
        nextHotKeyID &+= 1

        var hotKeyRef: EventHotKeyRef?
        let result = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if result == noErr, let ref = hotKeyRef {
            hotKeys[identifier] = ref
            hotKeyIDsByIdentifier[identifier] = hotKeyID.id
            hotKeyIdentifiersByID[hotKeyID.id] = identifier
        }
    }

    func unregisterHotKey(with identifier: String) {
        if let ref = hotKeys[identifier] {
            UnregisterEventHotKey(ref)
            hotKeys.removeValue(forKey: identifier)
        }
        if let id = hotKeyIDsByIdentifier.removeValue(forKey: identifier) {
            hotKeyIdentifiersByID.removeValue(forKey: id)
        }
    }

    func keyCode(_ keyCombo: KeyCombo) -> UInt32 {
        return UInt32(keyCombo.QWERTYKeyCode)
    }

    func carbonModifiers(_ keyCombo: KeyCombo) -> UInt32 {
        return UInt32(keyCombo.modifiers)
    }
}

// MARK: - Register
private extension HotKeyService {
    func register(with type: MenuType, keyCombo: KeyCombo?) {
        save(with: type, keyCombo: keyCombo)
        // Reset hotkey
        unregisterHotKey(with: type.rawValue)
        // Register new hotkey
        guard let keyCombo = keyCombo else { return }
        registerCarbonHotKey(identifier: type.rawValue, keyCode: keyCode(keyCombo), modifiers: carbonModifiers(keyCombo), action: type.hotKeySelector)
    }

    func save(with type: MenuType, keyCombo: KeyCombo?) {
        AppEnvironment.current.defaults.set(keyCombo?.archive(), forKey: type.userDefaultsKey)
        AppEnvironment.current.defaults.synchronize()
    }
}

// MARK: - Migration
private extension HotKeyService {
    /**
     *  Migration for changing the storage with v1.1.0
     *  Changed framework, PTHotKey to Magnet
     */
    func migrationKeyCombos() {
        guard let keyCombos = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.hotKeys) as? [String: Any] else { return }

        // Main menu
        if let (keyCode, modifiers) = parse(with: keyCombos, forKey: Constants.Menu.clip) {
            let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers)
            AppEnvironment.current.defaults.set(keyCombo.archive(), forKey: Constants.HotKey.mainKeyCombo)
        }
        // History menu
        if let (keyCode, modifiers) = parse(with: keyCombos, forKey: Constants.Menu.history) {
            let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers)
            AppEnvironment.current.defaults.set(keyCombo.archive(), forKey: Constants.HotKey.historyKeyCombo)
        }
        // Snippet menu
        if let (keyCode, modifiers) = parse(with: keyCombos, forKey: Constants.Menu.snippet) {
            let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers)
            AppEnvironment.current.defaults.set(keyCombo.archive(), forKey: Constants.HotKey.snippetKeyCombo)
        }
    }

    func parse(with keyCombos: [String: Any], forKey key: String) -> (Int, Int)? {
        guard let combos = keyCombos[key] as? [String: Any] else { return nil }
        guard let keyCode = combos["keyCode"] as? Int, let modifiers = combos["modifiers"] as? Int else { return nil }
        return (keyCode, modifiers)
    }
}

// MARK: - Snippet HotKey
extension HotKeyService {
    private var folderKeyCombos: [String: KeyCombo]? {
        get {
            guard let data = AppEnvironment.current.defaults.object(forKey: Constants.HotKey.folderKeyCombos) as? Data else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self, KeyCombo.self],
                from: data
            ) as? [String: KeyCombo]
        }
        set {
            if let value = newValue {
                AppEnvironment.current.defaults.set(
                    try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true),
                    forKey: Constants.HotKey.folderKeyCombos
                )
            } else {
                AppEnvironment.current.defaults.removeObject(forKey: Constants.HotKey.folderKeyCombos)
            }
            AppEnvironment.current.defaults.synchronize()
        }
    }

    func snippetKeyCombo(forIdentifier identifier: String) -> KeyCombo? {
        return folderKeyCombos?[identifier]
    }

    func registerSnippetHotKey(with identifier: String, keyCombo: KeyCombo) {
        // Reset hotkey
        unregisterSnippetHotKey(with: identifier)
        // Register new hotkey
        registerCarbonHotKey(identifier: identifier, keyCode: keyCode(keyCombo), modifiers: carbonModifiers(keyCombo), action: #selector(HotKeyService.popupSnippetFolder(_:)))
        // Save key combos
        var keyCombos = folderKeyCombos ?? [String: KeyCombo]()
        keyCombos[identifier] = keyCombo
        folderKeyCombos = keyCombos
    }

    func unregisterSnippetHotKey(with identifier: String) {
        // Unregister
        unregisterHotKey(with: identifier)
        // Save key combos
        var keyCombos = folderKeyCombos ?? [String: KeyCombo]()
        keyCombos.removeValue(forKey: identifier)
        folderKeyCombos = keyCombos
    }

    @objc func popupSnippetFolder(_ object: AnyObject) {
        guard let hotKey = object as? HotKey, let folderID = UUID(uuidString: hotKey.identifier) else { return }
        popupSnippetFolder(folderID: folderID)
    }

    private func popupSnippetFolder(folderID: UUID) {
        guard let folderDetail = snippetRepository.fetchFolderDetail(id: folderID) else {
            // When already deleted folder, remove keycombos
            unregisterSnippetHotKey(with: folderID.uuidString)
            return
        }
        guard folderDetail.folder.isEnabled else { return }
        AppEnvironment.current.menuManager.popUpSnippetFolder(folderDetail)
    }

    fileprivate func setupSnippetHotKeys() {
        folderKeyCombos?.forEach { identifier, keyCombo in
            registerCarbonHotKey(identifier: identifier, keyCode: keyCode(keyCombo), modifiers: carbonModifiers(keyCombo), action: #selector(HotKeyService.popupSnippetFolder(_:)))
        }
    }
}

// MARK: - KeyCombo (Minimal replacement for Magnet's KeyCombo)

final class KeyCombo: NSObject, NSSecureCoding {
    static let supportsSecureCoding = true

    let QWERTYKeyCode: Int
    let modifiers: Int

    init(QWERTYKeyCode: Int, carbonModifiers: Int) {
        self.QWERTYKeyCode = QWERTYKeyCode
        self.modifiers = carbonModifiers
        super.init()
    }

    init?(keyCode: Int, cocoaModifiers: NSEvent.ModifierFlags) {
        self.QWERTYKeyCode = keyCode
        var carbon: Int = 0
        if cocoaModifiers.contains(.command) { carbon |= cmdKey }
        if cocoaModifiers.contains(.option) { carbon |= optionKey }
        if cocoaModifiers.contains(.control) { carbon |= controlKey }
        if cocoaModifiers.contains(.shift) { carbon |= shiftKey }
        self.modifiers = carbon
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        self.QWERTYKeyCode = aDecoder.decodeInteger(forKey: "keyCode")
        self.modifiers = aDecoder.decodeInteger(forKey: "modifiers")
        super.init()
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(QWERTYKeyCode, forKey: "keyCode")
        aCoder.encode(modifiers, forKey: "modifiers")
    }
}

// MARK: - HotKey (Minimal placeholder for Magnet's HotKey)

final class HotKey: NSObject {
    let identifier: String
    let keyCombo: KeyCombo

    init(identifier: String, keyCombo: KeyCombo, target: AnyObject?, action: Selector?) {
        self.identifier = identifier
        self.keyCombo = keyCombo
        super.init()
    }
}
