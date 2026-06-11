//
//  ClipService.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Cocoa
import Foundation

final class ClipService {

    // MARK: - Properties
    fileprivate var cachedChangeCount = 0
    fileprivate var storeTypes = [String: NSNumber]()
    fileprivate var timer: Timer?
    fileprivate let lock = NSRecursiveLock(name: "com.knoseman.reclipt.ClipUpdatable")
    fileprivate var consecutiveNoChanges = 0

    private let pasteboardHistoryRepository = PasteboardHistoryRepository()

    // MARK: - Clips
    func startMonitoring() {
        stopMonitoring()
        reloadStoreTypes()
        scheduleTimer(interval: 0.5)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        consecutiveNoChanges = 0
    }

    func clearAll() {
        pasteboardHistoryRepository.deleteAll()
        try? FileManager.default.removeItem(atPath: ReCliptUtilities.applicationSupportFolder())
    }

    func delete(id: PasteboardHistory.ID) {
        pasteboardHistoryRepository.deleteHistory(id: id)
    }

    func incrementChangeCount() {
        cachedChangeCount += 1
    }

    func reloadStoreTypes() {
        storeTypes = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: NSNumber] ?? [:]
    }

    // MARK: - Private Timer Management

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != cachedChangeCount else {
            consecutiveNoChanges += 1
            adjustTimerIfNeeded()
            return
        }
        cachedChangeCount = currentChangeCount
        consecutiveNoChanges = 0
        scheduleTimer(interval: 0.5)
        create()
    }

    private func adjustTimerIfNeeded() {
        let currentInterval = timer?.timeInterval ?? 0.5
        if consecutiveNoChanges > 600 && currentInterval < 2.0 { // 5 min at 0.5s = 600 ticks
            scheduleTimer(interval: 2.0)
        } else if consecutiveNoChanges > 60 && currentInterval < 1.0 { // 30s at 0.5s = 60 ticks
            scheduleTimer(interval: 1.0)
        }
    }

}

// MARK: - Create Clip
extension ClipService {
    fileprivate func create() {
        lock.lock(); defer { lock.unlock() }

        let pasteboard = NSPasteboard.general
        let types = PasteboardAvailableType.availableTypes(
            from: pasteboard.types ?? pasteboard.pasteboardItems?.flatMap(\.types) ?? [],
            storeAvailableTypes: storeTypes.filter { $0.value.boolValue }.compactMap { PasteboardAvailableType(rawValue: $0.key) }
        )
        guard !types.isEmpty else { return }

        // Excluded application
        guard !AppEnvironment.current.excludeAppService.frontProcessIsExcludedApplication() else { return }
        // Special applications
        guard !AppEnvironment.current.excludeAppService.copiedProcessIsExcludedApplications(pasteboard: pasteboard) else { return }

        guard let content = PasteboardContent(pasteboard: pasteboard, types: types) else { return }
        save(content)
    }

    func create(with image: NSImage) {
        lock.lock(); defer { lock.unlock() }

        guard let content = PasteboardContent(image: image) else { return }
        save(content)
    }

    private func save(_ content: PasteboardContent) {
        // Copy already copied history
        let isCopySameHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.copySameHistory)
        let historyID = content.hash
        if pasteboardHistoryRepository.fetchHistory(id: historyID) != nil, !isCopySameHistory { return }

        // Don't save empty string history
        if content.isOnlyStringType && content.stringValue.isEmpty { return }

        // Overwrite same history
        let isOverwriteHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.overwriteSameHistory)
        let savedHash = isOverwriteHistory ? content.hash : UUID().uuidString

        let unixTime = Int(Date().timeIntervalSince1970)
        pasteboardHistoryRepository.save(id: savedHash, content: content, updateAt: unixTime)
    }
}
