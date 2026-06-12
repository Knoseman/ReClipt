//
//  SnippetTransfer.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/12.
//

import Foundation

struct SnippetTransferFolder: Equatable {
    var id: UUID?
    var title: String
    var index: Int?
    var isEnabled: Bool
    var snippets: [SnippetTransferSnippet]
}

struct SnippetTransferSnippet: Equatable {
    var id: UUID?
    var title: String
    var content: String
    var index: Int?
    var isEnabled: Bool
}

enum SnippetTransfer {
    enum TransferError: Error {
        case emptyDocument
        case invalidXML
        case invalidPlist
    }

    static func importFolders(from data: Data, fileExtension: String? = nil) throws -> [SnippetTransferFolder] {
        let normalizedExtension = fileExtension?.lowercased()
        if normalizedExtension == Constants.Xml.fileType {
            return try importXML(data)
        }
        if normalizedExtension == "plist" {
            return try importPlist(data)
        }

        if let folders = try? importXML(data) {
            return folders
        }
        return try importPlist(data)
    }

    static func exportXML(folders: [SnippetTransferFolder], exportedAt: Date = Date()) throws -> Data {
        let root = XMLElement(name: Constants.Xml.rootElement)
        root.addAttribute(XMLNode.attribute(withName: "format", stringValue: "reclipt-snippets") as! XMLNode)
        root.addAttribute(XMLNode.attribute(withName: "version", stringValue: "1") as! XMLNode)
        root.addAttribute(XMLNode.attribute(withName: "exportedAt", stringValue: iso8601Formatter.string(from: exportedAt)) as! XMLNode)

        for (folderIndex, folder) in folders.enumerated() {
            let folderElement = XMLElement(name: Constants.Xml.folderElement)
            if let id = folder.id {
                folderElement.addAttribute(XMLNode.attribute(withName: "id", stringValue: id.uuidString) as! XMLNode)
            }
            folderElement.addAttribute(XMLNode.attribute(withName: Constants.Common.index, stringValue: String(folder.index ?? folderIndex)) as! XMLNode)
            folderElement.addAttribute(XMLNode.attribute(withName: "enabled", stringValue: folder.isEnabled ? "true" : "false") as! XMLNode)
            folderElement.addChild(textElement(Constants.Xml.titleElement, folder.title))

            let snippetsElement = XMLElement(name: Constants.Xml.snippetsElement)
            for (snippetIndex, snippet) in folder.snippets.enumerated() {
                let snippetElement = XMLElement(name: Constants.Xml.snippetElement)
                if let id = snippet.id {
                    snippetElement.addAttribute(XMLNode.attribute(withName: "id", stringValue: id.uuidString) as! XMLNode)
                }
                snippetElement.addAttribute(XMLNode.attribute(withName: Constants.Common.index, stringValue: String(snippet.index ?? snippetIndex)) as! XMLNode)
                snippetElement.addAttribute(XMLNode.attribute(withName: "enabled", stringValue: snippet.isEnabled ? "true" : "false") as! XMLNode)
                snippetElement.addChild(textElement(Constants.Xml.titleElement, snippet.title))

                let contentElement = textElement(Constants.Xml.contentElement, snippet.content)
                contentElement.addAttribute(XMLNode.attribute(withName: Constants.Xml.type, stringValue: "text/plain") as! XMLNode)
                snippetElement.addChild(contentElement)
                snippetsElement.addChild(snippetElement)
            }
            folderElement.addChild(snippetsElement)
            root.addChild(folderElement)
        }

        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "utf-8"
        return document.xmlData(options: [.nodePrettyPrint])
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func textElement(_ name: String, _ string: String) -> XMLElement {
        let element = XMLElement(name: name)
        element.stringValue = string
        return element
    }

    private static func importXML(_ data: Data) throws -> [SnippetTransferFolder] {
        let parser = XMLParser(data: data)
        let delegate = SnippetTransferXMLParserDelegate()
        parser.delegate = delegate
        guard parser.parse(), delegate.parserError == nil else {
            throw delegate.parserError ?? TransferError.invalidXML
        }
        guard !delegate.folders.isEmpty else { throw TransferError.emptyDocument }
        return delegate.folders
    }

    private static func importPlist(_ data: Data) throws -> [SnippetTransferFolder] {
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] else {
            throw TransferError.invalidPlist
        }

        let folders = plist.compactMap { dict -> SnippetTransferFolder? in
            guard let title = dict[Constants.Common.title] as? String,
                  let snippets = dict[Constants.Common.snippets] as? [[String: String]] else { return nil }
            let snippetData = snippets.compactMap { snippetDict -> SnippetTransferSnippet? in
                guard let snippetTitle = snippetDict[Constants.Common.title],
                      let snippetContent = snippetDict[Constants.Common.content] else { return nil }
                return SnippetTransferSnippet(
                    id: nil,
                    title: snippetTitle,
                    content: snippetContent,
                    index: nil,
                    isEnabled: true
                )
            }
            return SnippetTransferFolder(
                id: nil,
                title: title,
                index: nil,
                isEnabled: true,
                snippets: snippetData
            )
        }

        guard !folders.isEmpty else { throw TransferError.emptyDocument }
        return folders
    }
}

private final class SnippetTransferXMLParserDelegate: NSObject, XMLParserDelegate {
    private enum TextTarget {
        case folderTitle
        case snippetTitle
        case snippetContent
    }

    private(set) var folders = [SnippetTransferFolder]()
    private(set) var parserError: Error?

    private var currentFolder: SnippetTransferFolder?
    private var currentSnippet: SnippetTransferSnippet?
    private var currentText = ""
    private var textTarget: TextTarget?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case Constants.Xml.rootElement, Constants.Xml.snippetsElement:
            break
        case Constants.Xml.folderElement:
            currentFolder = SnippetTransferFolder(
                id: uuid(attributeDict["id"]),
                title: "",
                index: int(attributeDict[Constants.Common.index]),
                isEnabled: bool(attributeDict["enabled"], defaultValue: true),
                snippets: []
            )
        case Constants.Xml.snippetElement:
            currentSnippet = SnippetTransferSnippet(
                id: uuid(attributeDict["id"]),
                title: "",
                content: "",
                index: int(attributeDict[Constants.Common.index]),
                isEnabled: bool(attributeDict["enabled"], defaultValue: true)
            )
        case Constants.Xml.titleElement:
            currentText = ""
            textTarget = currentSnippet == nil ? .folderTitle : .snippetTitle
        case Constants.Xml.contentElement:
            currentText = ""
            textTarget = .snippetContent
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard textTarget != nil else { return }
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard textTarget != nil, let string = String(data: CDATABlock, encoding: .utf8) else { return }
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case Constants.Xml.titleElement:
            switch textTarget {
            case .folderTitle:
                currentFolder?.title = currentText
            case .snippetTitle:
                currentSnippet?.title = currentText
            default:
                break
            }
            currentText = ""
            textTarget = nil
        case Constants.Xml.contentElement:
            currentSnippet?.content = currentText
            currentText = ""
            textTarget = nil
        case Constants.Xml.snippetElement:
            guard let snippet = currentSnippet else { return }
            currentFolder?.snippets.append(snippet)
            currentSnippet = nil
        case Constants.Xml.folderElement:
            guard let folder = currentFolder else { return }
            folders.append(folder)
            currentFolder = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = parseError
    }

    private func uuid(_ value: String?) -> UUID? {
        guard let value else { return nil }
        return UUID(uuidString: value)
    }

    private func int(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value)
    }

    private func bool(_ value: String?, defaultValue: Bool) -> Bool {
        guard let value else { return defaultValue }
        switch value.lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return defaultValue
        }
    }
}
