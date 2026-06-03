import AppKit
import ApplicationServices

public protocol AccessibilityPermissionChecking {
    func isAccessibilityTrusted(prompt: Bool) -> Bool
}

public final class PermissionManager: AccessibilityPermissionChecking {
    public init() {}

    public func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    public func showPermissionInstructions() {
        let alert = NSAlert()
        alert.messageText = "WhatsCopy needs Accessibility permission"
        alert.informativeText = """
        WhatsCopy uses macOS Accessibility only to read text you have actively selected in WhatsApp when you press Command-C.

        Enable WhatsCopy in System Settings > Privacy & Security > Accessibility, then restart WhatsCopy if needed.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    public func showTrustedConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Accessibility permission is enabled"
        alert.informativeText = "WhatsCopy can now restore Command-C for selected text exposed by WhatsApp."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    public func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
