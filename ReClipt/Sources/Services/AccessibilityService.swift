// 
//  AccessibilityService.swift
//
//  ReClipt
// 
//  Created by ReClipt on 2026/06/11.
// 
//  Copyright © 2026 ReClipt Project.
//

import Cocoa
import Foundation

final class AccessibilityService {
    private var hasShownAccessibilityAlertThisSession = false
    private var hasShownPasteFallbackAlertThisSession = false
}

// MARK: - Permission
extension AccessibilityService {
    // Accessibility permission is required for simulating paste (Cmd+V) via CGEvent from macOS 10.14 Mojave.
    @discardableResult
    func isAccessibilityEnabled(isPrompt: Bool) -> Bool {
        guard #available(macOS 10.14, *) else { return true }

        let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [checkOptionPromptKey: false] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            return true
        }
        // AXIsProcessTrustedWithOptions can lag behind the actual TCC state.
        // Probe a harmless accessibility attribute before showing a prompt.
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedApplicationAttribute as CFString,
            &value
        )
        // .success means an app has focus and we got it — trust is granted.
        // .noValue means no app has focus (e.g. menu just closed) but the API
        // accepted the call — trust is still granted.
        // .apiDisabled or .cannotComplete means no trust.
        if result == .success || result == .noValue {
            return true
        }
        if isPrompt && !hasShownAccessibilityAlertThisSession {
            let promptOpts = [checkOptionPromptKey: true] as CFDictionary
            AXIsProcessTrustedWithOptions(promptOpts)
            hasShownAccessibilityAlertThisSession = true
        }
        return false
    }

    func showAccessibilityAuthenticationAlert() {
        guard !hasShownAccessibilityAlertThisSession else { return }
        hasShownAccessibilityAlertThisSession = true

        let alert = NSAlert()
        alert.messageText = String(localized: "Please allow Accessibility")
        alert.informativeText = String(localized: "To paste snippets, allow ReClipt in System Settings > Privacy & Security > Accessibility. If you just enabled it, quit and reopen ReClipt before testing again.")
        alert.addButton(withTitle: String(localized: "Open System Preferences"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            guard !openAccessibilitySettingWindow() else { return }
            let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let promptOpts = [checkOptionPromptKey: true] as CFDictionary
            AXIsProcessTrustedWithOptions(promptOpts)
        }
    }

    func openAccessibilitySettingWindow() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return false }
        return NSWorkspace.shared.open(url)
    }

    func showPasteFallbackAlert() {
        guard !hasShownPasteFallbackAlertThisSession else { return }
        hasShownPasteFallbackAlertThisSession = true

        let alert = NSAlert()
        alert.messageText = String(localized: "Snippet copied to clipboard")
        alert.informativeText = String(localized: "Automatic paste is unavailable because macOS Accessibility trust is not resolving for the current app identity. The snippet is already on your clipboard. Press Command-V to paste it manually.")
        alert.addButton(withTitle: String(localized: "Open System Preferences"))
        alert.addButton(withTitle: String(localized: "OK"))
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            _ = openAccessibilitySettingWindow()
        }
    }
}
