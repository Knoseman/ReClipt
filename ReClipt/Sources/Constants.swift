//
//  Constants.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation

struct Constants {

    struct Application {
        #if DEBUG
            static let name = "ReCliptDEBUG"
        #else
            static let name = "ReClipt"
        #endif
    }

    struct Menu {
        static let clip = "ReCliptMenu"
        static let history = "HistoryMenu"
        static let snippet = "SnippetsMenu"
    }

    struct Common {
        static let index = "index"
        static let title = "title"
        static let snippets = "snippets"
        static let content = "content"
        static let selector = "selector"
        static let draggedDataType = "public.data"
    }

    struct UserDefaults {
        static let hotKeys = "kReCliptPrefHotKeysKey"
        static let menuIconSize = "kReCliptPrefMenuIconSizeKey"
        static let maxHistorySize = "kReCliptPrefMaxHistorySizeKey"
        static let storeTypes = "kReCliptPrefStoreTypesKey"
        static let inputPasteCommand = "kReCliptPrefInputPasteCommandKey"
        static let showIconInTheMenu = "kReCliptPrefShowIconInTheMenuKey"
        static let numberOfItemsPlaceInline = "kReCliptPrefNumberOfItemsPlaceInlineKey"
        static let numberOfItemsPlaceInsideFolder  = "kReCliptPrefNumberOfItemsPlaceInsideFolderKey"
        static let maxMenuItemTitleLength = "kReCliptPrefMaxMenuItemTitleLengthKey"
        static let menuItemsTitleStartWithZero = "kReCliptPrefMenuItemsTitleStartWithZeroKey"
        static let reorderClipsAfterPasting = "kReCliptPrefReorderClipsAfterPasting"
        static let addClearHistoryMenuItem = "kReCliptPrefAddClearHistoryMenuItemKey"
        static let showAlertBeforeClearHistory = "kReCliptPrefShowAlertBeforeClearHistoryKey"
        static let menuItemsAreMarkedWithNumbers = "menuItemsAreMarkedWithNumbers"
        static let showToolTipOnMenuItem = "showToolTipOnMenuItem"
        static let showImageInTheMenu = "showImageInTheMenu"
        static let addNumericKeyEquivalents = "addNumericKeyEquivalents"
        static let maxLengthOfToolTip = "maxLengthOfToolTipKey"
        static let showStatusItem = "kReCliptPrefShowStatusItemKey"
        static let thumbnailWidth = "thumbnailWidth"
        static let thumbnailHeight = "thumbnailHeight"
        static let overwriteSameHistory = "kReCliptPrefOverwriteSameHistroy"
        static let copySameHistory = "kReCliptPrefCopySameHistroy"
        static let suppressAlertForDeleteSnippet = "kReCliptSuppressAlertForDeleteSnippet"
        static let excludeApplications = "kReCliptExcludeApplications"
        static let showColorPreviewInTheMenu = "kReCliptPrefShowColorPreviewInTheMenu"
    }

    struct Beta {
        static let pastePlainText = "kReCliptBetaPastePlainText"
        static let pastePlainTextModifier = "kReCliptBetaPastePlainTextModifier"
        static let deleteHistory = "kReCliptBetaDeleteHistory"
        static let deleteHistoryModifier = "kReCliptBetaDeleteHistoryModifier"
        static let pasteAndDeleteHistory = "kReCliptBetaPasteAndDeleteHistory"
        static let pasteAndDeleteHistoryModifier = "kReCliptBetapasteAndDeleteHistoryModifier"
        static let observerScreenshot = "kReCliptBetaObserveScreenshot"
    }

    struct Update {
        static let enableAutomaticCheck = "kReCliptEnableAutomaticCheckKey"
        static let checkInterval = "kReCliptUpdateCheckIntervalKey"
    }

    struct Notification {
        static let closeSnippetEditor = "kReCliptSnippetEditorWillCloseNotification"
    }

    struct Xml {
        static let fileType = "xml"
        static let type = "type"
        static let rootElement = "folders"
        static let folderElement = "folder"
        static let snippetElement = "snippet"
        static let titleElement = "title"
        static let snippetsElement = "snippets"
        static let contentElement = "content"
    }

    struct HotKey {
        static let mainKeyCombo = "kReCliptHotKeyMainKeyCombo"
        static let historyKeyCombo = "kReCliptHotKeyHistoryKeyCombo"
        static let snippetKeyCombo = "kReCliptHotKeySnippetKeyCombo"
        static let migrateNewKeyCombo = "kReCliptMigrateNewKeyCombo"
        static let folderKeyCombos = "kReCliptFolderKeyCombos"
        static let clearHistoryKeyCombo = "kReCliptClearHistoryKeyCombo"
    }

}
