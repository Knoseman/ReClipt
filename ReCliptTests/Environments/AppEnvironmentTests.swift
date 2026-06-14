//
//  AppEnvironmentTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/14.
//
//  Copyright © 2026 ReClipt Project.
//

import AppKit
import Foundation
import Testing
@testable import ReClipt

@MainActor
@Suite(.serialized)
struct AppEnvironmentTests {
    @Test
    func fromStorageUsesProvidedDefaultsAndLoadsExcludedApps() throws {
        let defaults = try makeDefaults("FromStorageUsesProvidedDefaultsAndLoadsExcludedApps")
        defer { removeDefaults(defaults, suiteName: "FromStorageUsesProvidedDefaultsAndLoadsExcludedApps") }

        let appInfo = try makeAppInfo(identifier: "com.example.mail", name: "Mail")
        defaults.set([appInfo].archive(), forKey: Constants.UserDefaults.excludeApplications)

        let environment = AppEnvironment.fromStorage(defaults: defaults)
        #expect(environment.defaults === defaults)

        AppEnvironment.push(environment: environment)
        defer { _ = AppEnvironment.popLast() }

        let viewController = ExcludeAppPreferenceViewController()
        #expect(viewController.numberOfRows(in: NSTableView()) == 1)
        #expect(viewController.tableView(NSTableView(), objectValueFor: nil, row: 0) as? String == "Mail")
    }

    @Test
    func excludeAppServicePersistsAddsWithoutDuplicatesAndDeletesByIndex() throws {
        let defaults = try makeDefaults("ExcludeAppServicePersistsAddsWithoutDuplicatesAndDeletesByIndex")
        defer { removeDefaults(defaults, suiteName: "ExcludeAppServicePersistsAddsWithoutDuplicatesAndDeletesByIndex") }

        let service = ExcludeAppService(applications: [])
        AppEnvironment.push(excludeAppService: service, defaults: defaults)
        defer { _ = AppEnvironment.popLast() }

        let notes = try makeAppInfo(identifier: "com.example.notes", name: "Notes")
        let browser = try makeAppInfo(identifier: "com.example.browser", name: "Browser")

        service.add(with: notes)
        service.add(with: notes)
        service.add(with: browser)

        var savedApplications = try savedExcludedApplications(in: defaults)
        #expect(savedApplications.map(\.identifier) == ["com.example.notes", "com.example.browser"])

        service.delete(with: 0)
        service.delete(with: 42)

        savedApplications = try savedExcludedApplications(in: defaults)
        #expect(savedApplications.map(\.identifier) == ["com.example.browser"])
    }
}

private extension AppEnvironmentTests {
    func makeDefaults(_ suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func removeDefaults(_ defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func makeAppInfo(identifier: String, name: String) throws -> ReCliptAppInfo {
        try #require(ReCliptAppInfo(info: [
            kCFBundleIdentifierKey as String: identifier as NSString,
            kCFBundleNameKey as String: name as NSString
        ]))
    }

    func savedExcludedApplications(in defaults: UserDefaults) throws -> [ReCliptAppInfo] {
        let data = try #require(defaults.object(forKey: Constants.UserDefaults.excludeApplications) as? Data)
        return try #require(NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, ReCliptAppInfo.self, NSString.self],
            from: data
        ) as? [ReCliptAppInfo])
    }
}
