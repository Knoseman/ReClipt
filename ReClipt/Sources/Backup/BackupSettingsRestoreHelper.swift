//
//  BackupSettingsRestoreHelper.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/15.
//

import Foundation

enum BackupSettingsRestoreHelper {
    static func restore(_ settings: BackupSettings, to defaults: UserDefaults = AppEnvironment.current.defaults) {
        for (key, value) in settings.bools where boolKeys.contains(key) {
            defaults.set(value, forKey: key)
        }
        for (key, value) in settings.integers where integerKeys.contains(key) {
            defaults.set(value, forKey: key)
        }
        for (key, value) in settings.strings where stringKeys.contains(key) {
            defaults.set(value, forKey: key)
        }
        for (key, value) in settings.stringArrays where stringArrayKeys.contains(key) {
            defaults.set(value, forKey: key)
        }

        if settings.stringArrays.keys.contains(Constants.UserDefaults.storeTypes) {
            restoreStoreTypes(settings.stringArrays[Constants.UserDefaults.storeTypes] ?? [], to: defaults)
        }

        let restoredApplications = settings.excludedApplications.compactMap(makeApplication)
        let applications = mergedApplications(existingApplications(in: defaults), restoredApplications)
        let data = (try? NSKeyedArchiver.archivedData(
            withRootObject: applications,
            requiringSecureCoding: true
        )) ?? Data()
        defaults.set(data, forKey: Constants.UserDefaults.excludeApplications)
        defaults.synchronize()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
    }

    private static let boolKeys = Set(BackupSettingsExporter.boolKeys)
    private static let integerKeys = Set(BackupSettingsExporter.integerKeys)
    private static let stringKeys = Set(BackupSettingsExporter.stringKeys)
    private static let stringArrayKeys = Set(BackupSettingsExporter.stringArrayKeys)

    private static func restoreStoreTypes(_ enabledTypes: [String], to defaults: UserDefaults) {
        let enabledSet = Set(enabledTypes)
        var storeTypes = [String: Bool]()
        if let existing = defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: Any] {
            for key in existing.keys {
                storeTypes[key] = enabledSet.contains(key)
            }
        }
        for key in enabledSet {
            storeTypes[key] = true
        }
        defaults.set(storeTypes, forKey: Constants.UserDefaults.storeTypes)
    }

    private static func existingApplications(in defaults: UserDefaults) -> [ReCliptAppInfo] {
        guard let data = defaults.object(forKey: Constants.UserDefaults.excludeApplications) as? Data else { return [] }
        return (try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, ReCliptAppInfo.self, NSString.self],
            from: data
        ) as? [ReCliptAppInfo]) ?? []
    }

    private static func mergedApplications(
        _ existing: [ReCliptAppInfo],
        _ restored: [ReCliptAppInfo]
    ) -> [ReCliptAppInfo] {
        var applications = existing
        for application in restored where !applications.contains(application) {
            applications.append(application)
        }
        return applications
    }

    private static func makeApplication(_ application: BackupExcludedApplication) -> ReCliptAppInfo? {
        ReCliptAppInfo(info: [
            kCFBundleIdentifierKey as String: application.identifier as NSString,
            kCFBundleNameKey as String: application.name as NSString
        ])
    }
}
