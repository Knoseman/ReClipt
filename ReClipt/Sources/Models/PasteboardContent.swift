//
//  PasteboardContent.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2015-2026 ReClipt Project.
//

import Cocoa
import CryptoKit
import Foundation

struct PasteboardContent: Equatable {
    struct Asset: Equatable {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    // MARK: - Properties
    let types: [NSPasteboard.PasteboardType]
    let assets: [Asset]
    let hash: String

    var isOnlyStringType: Bool {
        types == [.string] || types == [.deprecatedString]
    }
    var stringValue: String {
        guard let data = data(for: .string) ?? data(for: .deprecatedString) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    var colorCodeImage: NSImage? {
        guard let color = NSColor.hexString(stringValue) else { return nil }
        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
    }
    var thumbnailImage: NSImage? {
        let defaults = UserDefaults.standard
        let width = defaults.integer(forKey: Constants.UserDefaults.thumbnailWidth)
        let height = defaults.integer(forKey: Constants.UserDefaults.thumbnailHeight)

        let imageURL = assets.filter { $0.type == .fileURL }
            .compactMap { URL(dataRepresentation: $0.data, relativeTo: nil) }
            .first(where: { ["jpg", "jpeg", "png", "bmp", "tiff"].contains($0.pathExtension.lowercased()) })
        if let imageURL {
            return NSImage(contentsOf: imageURL)?.resizeImage(CGFloat(width), CGFloat(height))
        } else if let data = data(for: .png) ?? data(for: .tiff) ?? data(for: .deprecatedTIFF) {
            return NSImage(data: data)?.resizeImage(CGFloat(width), CGFloat(height))
        }
        return nil
    }
    var pasteboardItems: [NSPasteboardItem] {
        var countsByType: [NSPasteboard.PasteboardType: Int] = [:]
        // History assets intentionally do not persist the original NSPasteboardItem boundaries.
        // Replaying groups assets by each pasteboard type's occurrence index, which keeps
        // multi-item file writes working without making item boundaries part of the schema.
        return assets
            .filter { $0.type != .deprecatedFilenames }
            .reduce(into: [NSPasteboardItem]()) { items, asset in
                let index = countsByType[asset.type] ?? 0
                countsByType[asset.type] = index + 1
                if !items.indices.contains(index) {
                    items.append(NSPasteboardItem())
                }
                items[index].setData(asset.data, forType: asset.type)
            }
    }

    // MARK: - Initialize
    init?(assets: [Asset]) {
        guard !assets.isEmpty else { return nil }
        self.types = assets.map(\.type)
        self.assets = assets
        var data = Data()
        assets.forEach { asset in
            data.append(value: Data(asset.type.rawValue.utf8))
            data.append(value: asset.data)
        }
        self.hash = data.sha256Hex
    }

    init?(pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) {
        let itemAssets = pasteboard.pasteboardItems?.compactMap { item -> [Asset]? in
            item.types.filter { types.contains($0) }
                .compactMap { type -> Asset? in
                    guard let data = item.data(forType: type) else { return nil }
                    return Asset(type: type, data: data)
                }
        }
        .flatMap { $0 } ?? []
        // Fall back to the pasteboard root for types that may only be available there,
        // such as .tiff and .deprecatedFilenames.
        let itemAssetTypes = itemAssets.map(\.type)
        let rootAssets = types
            .filter { !itemAssetTypes.contains($0) }
            .compactMap { type -> Asset? in
                guard let data = pasteboard.data(forType: type) else { return nil }
                return Asset(type: type, data: data)
            }
        let assets = (itemAssets + rootAssets).sorted(by: types)
        guard !assets.isEmpty else { return nil }
        self.init(assets: assets)
    }

    init?(image: NSImage) {
        guard let data = image.tiffRepresentation else { return nil }
        self.init(assets: [Asset(type: .tiff, data: data)])
    }
}

extension PasteboardContent {
    func writeObjects(to pasteboard: NSPasteboard) {
        let pasteboardItems = self.pasteboardItems
        let filenamesAsset = self.assets.first(where: { $0.type == .deprecatedFilenames })

        pasteboard.clearContents()
        // File URLs are normally written as per-item fileURL data.
        // Keep NSFilenamesPboardType on the pasteboard root for stored filename entries
        // and apps that only understand the deprecated filenames flavor.
        if let filenamesAsset {
            pasteboard.setData(filenamesAsset.data, forType: filenamesAsset.type)
        }
        pasteboard.writeObjects(pasteboardItems)
    }
}

private extension PasteboardContent {
    func data(for type: NSPasteboard.PasteboardType) -> Data? {
        assets.first(where: { $0.type == type })?.data
    }
}

private extension [PasteboardContent.Asset] {
    func sorted(by types: [NSPasteboard.PasteboardType]) -> Self {
        types.flatMap { type in
            filter { $0.type == type }
        }
    }
}

private extension Data {
    mutating func append(value: Data) {
        var length = UInt64(value.count).bigEndian
        Swift.withUnsafeBytes(of: &length) {
            append(contentsOf: $0)
        }
        append(value)
    }

    var sha256Hex: String {
        SHA256.hash(data: self)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - NSColor Hex Parser (replaces SwiftHEXColors)

extension NSColor {
    static func hexString(_ hex: String) -> NSColor? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&rgb) else { return nil }

        let length = trimmed.count
        var r, g, b, a: CGFloat

        switch length {
        case 3:
            r = CGFloat((rgb & 0xF00) >> 8) / 15.0
            g = CGFloat((rgb & 0x0F0) >> 4) / 15.0
            b = CGFloat(rgb & 0x00F) / 15.0
            a = 1.0
        case 4:
            r = CGFloat((rgb & 0xF000) >> 12) / 15.0
            g = CGFloat((rgb & 0x0F00) >> 8) / 15.0
            b = CGFloat((rgb & 0x00F0) >> 4) / 15.0
            a = CGFloat(rgb & 0x000F) / 15.0
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
