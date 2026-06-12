//
//  SnippetTransferTests.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/12.
//

import Foundation
import Testing
@testable import ReClipt

struct SnippetTransferTests {
    @Test
    func importsClipyXML() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8" standalone="no"?>
        <folders>
            <folder>
                <title>Common</title>
                <snippets>
                    <snippet>
                        <title>Email</title>
                        <content>cristian@example.com</content>
                    </snippet>
                    <snippet>
                        <title>Command</title>
                        <content>ollama run qwen3:8b</content>
                    </snippet>
                </snippets>
            </folder>
        </folders>
        """

        let folders = try SnippetTransfer.importFolders(from: Data(xml.utf8), fileExtension: "xml")

        #expect(folders.count == 1)
        #expect(folders[0].title == "Common")
        #expect(folders[0].isEnabled)
        #expect(folders[0].snippets.count == 2)
        #expect(folders[0].snippets[0].title == "Email")
        #expect(folders[0].snippets[0].content == "cristian@example.com")
        #expect(folders[0].snippets[1].content == "ollama run qwen3:8b")
    }

    @Test
    func importsExtendedReCliptXML() throws {
        let folderID = UUID()
        let snippetID = UUID()
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <folders format="reclipt-snippets" version="1" exportedAt="2026-06-12T08:30:00Z">
            <folder id="\(folderID.uuidString)" index="4" enabled="false">
                <title>Logins</title>
                <snippets>
                    <snippet id="\(snippetID.uuidString)" index="2" enabled="false">
                        <title>UIGP - P</title>
                        <content type="text/plain">Sk!tlosen@!!</content>
                    </snippet>
                </snippets>
            </folder>
        </folders>
        """

        let folders = try SnippetTransfer.importFolders(from: Data(xml.utf8), fileExtension: "xml")

        #expect(folders.count == 1)
        #expect(folders[0].id == folderID)
        #expect(folders[0].index == 4)
        #expect(!folders[0].isEnabled)
        #expect(folders[0].snippets[0].id == snippetID)
        #expect(folders[0].snippets[0].index == 2)
        #expect(!folders[0].snippets[0].isEnabled)
    }

    @Test
    func exportsAndImportsReCliptXML() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let source = [
            SnippetTransferFolder(
                id: UUID(),
                title: "AI",
                index: 0,
                isEnabled: true,
                snippets: [
                    SnippetTransferSnippet(
                        id: UUID(),
                        title: "LiteLLM router",
                        content: "litellm --model ollama/qwen2.5-coder:14b --port 4000",
                        index: 0,
                        isEnabled: true
                    )
                ]
            )
        ]

        let data = try SnippetTransfer.exportXML(folders: source, exportedAt: exportedAt)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("format=\"reclipt-snippets\""))
        #expect(xml.contains("version=\"1\""))
        #expect(xml.contains("<title>AI</title>"))

        let imported = try SnippetTransfer.importFolders(from: data, fileExtension: "xml")
        #expect(imported == source)
    }

    @Test
    func importsLegacyReCliptPlist() throws {
        let plist: [[String: Any]] = [
            [
                "title": "Common",
                "snippets": [
                    [
                        "title": "Phone",
                        "content": "+46 76 881 25 20"
                    ]
                ]
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

        let folders = try SnippetTransfer.importFolders(from: data, fileExtension: "plist")

        #expect(folders.count == 1)
        #expect(folders[0].title == "Common")
        #expect(folders[0].snippets[0].title == "Phone")
        #expect(folders[0].snippets[0].content == "+46 76 881 25 20")
    }
}
