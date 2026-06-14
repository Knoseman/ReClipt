//
//  PasteServiceTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/14.
//
//  Copyright © 2026 ReClipt Project.
//

import AppKit
import Testing
@testable import ReClipt

@Suite(.serialized)
struct PasteServiceTests {
    @Test
    func copyToPasteboardWritesStringOnly() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        PasteService().copyToPasteboard(with: "Plain Text")

        #expect(pasteboard.string(forType: .string) == "Plain Text")
        #expect(pasteboard.types?.contains(.string) == true)
    }
}
