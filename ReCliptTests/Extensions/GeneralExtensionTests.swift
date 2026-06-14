//
//  GeneralExtensionTests.swift
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

@Suite
struct GeneralExtensionTests {
    @Test
    func safeSubscriptReturnsElementOnlyWhenIndexExists() {
        let values = ["first", "second"]

        #expect(values[safe: 0] == "first")
        #expect(values[safe: 1] == "second")
        #expect(values[safe: 2] == nil)
        #expect(values[safe: -1] == nil)
    }

    @Test
    func closedRangeStringSubscriptIncludesUpperBoundAndClampsToBounds() {
        let value = "ReClipt"

        #expect(value[0...2] == "ReC")
        #expect(value[2...99] == "Clipt")
        #expect(value[-4...1] == "Re")
        #expect(value[20...30] == "")
        #expect(""[0...2] == "")
    }

    @Test
    func recursiveLockConvenienceInitializerSetsName() {
        let lock = NSRecursiveLock(name: "com.knoseman.reclipt.tests")

        #expect(lock.name == "com.knoseman.reclipt.tests")
    }

    @Test
    func menuItemConvenienceInitializerUsesEmptyKeyEquivalent() {
        let item = NSMenuItem(title: "Copy", action: #selector(NSObject.copy))

        #expect(item.title == "Copy")
        #expect(item.action == #selector(NSObject.copy))
        #expect(item.keyEquivalent == "")
    }

    @Test
    func deprecatedPasteboardTypesKeepLegacyRawValues() {
        #expect(NSPasteboard.PasteboardType.deprecatedString.rawValue == "NSStringPboardType")
        #expect(NSPasteboard.PasteboardType.deprecatedRTF.rawValue == "NSRTFPboardType")
        #expect(NSPasteboard.PasteboardType.deprecatedRTFD.rawValue == "NSRTFDPboardType")
        #expect(NSPasteboard.PasteboardType.deprecatedPDF.rawValue == "NSPDFPboardType")
        #expect(NSPasteboard.PasteboardType.deprecatedFilenames.rawValue == "NSFilenamesPboardType")
        #expect(NSPasteboard.PasteboardType.deprecatedURL.rawValue == "NSURLPboardType")
        #expect(NSPasteboard.PasteboardType.deprecatedTIFF.rawValue == "NSTIFFPboardType")
    }

    @Test
    func archiveHelpersRoundTripSecureCodingObjects() throws {
        let appInfo = try makeAppInfo(identifier: "com.example.archive", name: "Archive")

        let data = appInfo.archive()
        let unarchived = try #require(try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ReCliptAppInfo.self,
            from: data
        ))
        #expect(unarchived == appInfo)

        let arrayData = [appInfo].archive()
        let unarchivedArray = try #require(try NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, ReCliptAppInfo.self, NSString.self],
            from: arrayData
        ) as? [ReCliptAppInfo])
        #expect(unarchivedArray == [appInfo])
    }

    @Test
    func userDefaultsArchiveHelpersRoundTripObject() throws {
        let suiteName = "UserDefaultsArchiveHelpersRoundTripObject"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let appInfo = try makeAppInfo(identifier: "com.example.defaults", name: "Defaults")
        defaults.setArchiveData(appInfo, forKey: "app")

        let unarchived = try #require(defaults.archiveDataForKey(ReCliptAppInfo.self, key: "app"))
        #expect(unarchived == appInfo)
    }

    @Test
    func imageCreatedFromColorUsesRequestedSize() {
        let image = NSImage.create(with: .systemRed, size: NSSize(width: 12, height: 8))

        #expect(image.size == NSSize(width: 12, height: 8))
        #expect(image.tiffRepresentation != nil)
    }
}

private func makeAppInfo(identifier: String, name: String) throws -> ReCliptAppInfo {
    try #require(ReCliptAppInfo(info: [
        kCFBundleIdentifierKey as String: identifier as NSString,
        kCFBundleNameKey as String: name as NSString
    ]))
}
