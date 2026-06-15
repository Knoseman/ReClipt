//
//  BackupSettingsExporter.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/15.
//

import Foundation

struct BackupSettingsExporter {
    let defaults: UserDefaults

    init(defaults: UserDefaults = AppEnvironment.current.defaults) {
        self.defaults = defaults
    }

    func exportSettings() -> BackupSettings {
        var settings = BackupSettings()

        for key in Self.boolKeys where defaults.object(forKey: key) != nil {
            settings.bools[key] = defaults.bool(forKey: key)
        }

        for key in Self.integerKeys where defaults.object(forKey: key) != nil {
            settings.integers[key] = defaults.integer(forKey: key)
        }

        for key in Self.stringKeys {
            if let value = defaults.string(forKey: key) {
                settings.strings[key] = value
            }
        }

        for key in Self.stringArrayKeys {
            if let value = defaults.stringArray(forKey: key) {
                settings.stringArrays[key] = value
            }
        }

        if let enabledTypes = enabledStoreTypes() {
            settings.stringArrays[Constants.UserDefaults.storeTypes] = enabledTypes
        }

        settings.excludedApplications = excludedApplications()
        return settings
    }

    private func enabledStoreTypes() -> [String]? {
        guard let value = defaults.object(forKey: Constants.UserDefaults.storeTypes) else { return nil }
        guard let dictionary = value as? [String: Any] else { return [] }
        return dictionary.compactMap { key, value in
            if let number = value as? NSNumber, number.boolValue { return key }
            if let bool = value as? Bool, bool { return key }
            return nil
        }.sorted()
    }

    private func excludedApplications() -> [BackupExcludedApplication] {
        guard let data = defaults.object(forKey: Constants.UserDefaults.excludeApplications) as? Data else { return [] }
        let classes: [AnyClass] = [NSArray.self, ReCliptAppInfo.self, NSString.self]
        guard let applications = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: classes,
            from: data
        ) as? [ReCliptAppInfo] else { return [] }

        return applications.map {
            BackupExcludedApplication(identifier: $0.identifier, name: $0.name)
        }
    }
}

extension BackupSettingsExporter {
    static let boolKeys: [String] = [
        Constants.UserDefaults.inputPasteCommand,
        Constants.UserDefaults.showIconInTheMenu,
        Constants.UserDefaults.menuItemsTitleStartWithZero,
        Constants.UserDefaults.reorderClipsAfterPasting,
        Constants.UserDefaults.addClearHistoryMenuItem,
        Constants.UserDefaults.showAlertBeforeClearHistory,
        Constants.UserDefaults.menuItemsAreMarkedWithNumbers,
        Constants.UserDefaults.showToolTipOnMenuItem,
        Constants.UserDefaults.showImageInTheMenu,
        Constants.UserDefaults.addNumericKeyEquivalents,
        Constants.UserDefaults.overwriteSameHistory,
        Constants.UserDefaults.copySameHistory,
        Constants.UserDefaults.showColorPreviewInTheMenu
    ]

    static let integerKeys: [String] = [
        Constants.UserDefaults.menuIconSize,
        Constants.UserDefaults.maxHistorySize,
        Constants.UserDefaults.showStatusItem,
        Constants.UserDefaults.numberOfItemsPlaceInline,
        Constants.UserDefaults.numberOfItemsPlaceInsideFolder,
        Constants.UserDefaults.maxMenuItemTitleLength,
        Constants.UserDefaults.maxLengthOfToolTip,
        Constants.UserDefaults.thumbnailWidth,
        Constants.UserDefaults.thumbnailHeight
    ]

    static let stringKeys: [String] = []
    static let stringArrayKeys: [String] = []
}
