//
//  ReCliptAppInfoTests.swift
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
struct ReCliptAppInfoTests {
    @Test
    func initializesFromBundleNameOrExecutableFallback() throws {
        let namedApp = try #require(ReCliptAppInfo(info: [
            kCFBundleIdentifierKey as String: "com.example.named" as NSString,
            kCFBundleNameKey as String: "Named App" as NSString
        ]))
        #expect(namedApp.identifier == "com.example.named")
        #expect(namedApp.name == "Named App")

        let executableApp = try #require(ReCliptAppInfo(info: [
            kCFBundleIdentifierKey as String: "com.example.executable" as NSString,
            kCFBundleExecutableKey as String: "ExecutableApp" as NSString
        ]))
        #expect(executableApp.identifier == "com.example.executable")
        #expect(executableApp.name == "ExecutableApp")
    }

    @Test
    func rejectsIncompleteBundleInfo() {
        #expect(ReCliptAppInfo(info: [
            kCFBundleNameKey as String: "Missing Identifier" as NSString
        ]) == nil)

        #expect(ReCliptAppInfo(info: [
            kCFBundleIdentifierKey as String: "com.example.missing-name" as NSString
        ]) == nil)
    }

    @Test
    func equalityUsesIdentifierAndName() throws {
        let appInfo = try makeAppInfo(identifier: "com.example.same", name: "Same")
        let same = try makeAppInfo(identifier: "com.example.same", name: "Same")
        let differentIdentifier = try makeAppInfo(identifier: "com.example.other", name: "Same")
        let differentName = try makeAppInfo(identifier: "com.example.same", name: "Other")

        #expect(appInfo == same)
        #expect(appInfo != differentIdentifier)
        #expect(appInfo != differentName)
        #expect(appInfo != NSObject())
    }

    @Test
    func secureCodingRoundTripsIdentifierAndName() throws {
        let appInfo = try makeAppInfo(identifier: "com.example.secure", name: "Secure")
        let data = try NSKeyedArchiver.archivedData(withRootObject: appInfo, requiringSecureCoding: true)

        let unarchived = try #require(try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ReCliptAppInfo.self,
            from: data
        ))
        #expect(unarchived.identifier == appInfo.identifier)
        #expect(unarchived.name == appInfo.name)
    }
}

private func makeAppInfo(identifier: String, name: String) throws -> ReCliptAppInfo {
    try #require(ReCliptAppInfo(info: [
        kCFBundleIdentifierKey as String: identifier as NSString,
        kCFBundleNameKey as String: name as NSString
    ]))
}
