//
//  DraggedData.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

final class DraggedData: NSObject, NSSecureCoding {
    // MARK: - Properties
    static let supportsSecureCoding: Bool = true

    let type: DragType
    let folderID: SnippetFolder.ID?
    let snippetID: Snippet.ID?
    let index: Int

    // MARK: - Enums
    enum DragType: Int {
        case folder, snippet
    }

    // MARK: - Initialize
    init(type: DragType, folderID: SnippetFolder.ID?, snippetID: Snippet.ID?, index: Int) {
        self.type = type
        self.folderID = folderID
        self.snippetID = snippetID
        self.index = index
        super.init()
    }

    // MARK: - NSCoding
    required init?(coder aDecoder: NSCoder) {
        self.type = DragType(rawValue: aDecoder.decodeInteger(forKey: "type")) ?? .folder
        self.folderID = aDecoder.decodeObject(forKey: "folderID") as? UUID
        self.snippetID = aDecoder.decodeObject(forKey: "snippetID") as? UUID
        self.index = aDecoder.decodeInteger(forKey: "index")
        super.init()
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(type.rawValue, forKey: "type")
        aCoder.encode(folderID, forKey: "folderID")
        aCoder.encode(snippetID, forKey: "snippetID")
        aCoder.encode(index, forKey: "index")
    }
}
