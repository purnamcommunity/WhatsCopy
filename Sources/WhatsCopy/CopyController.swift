import Foundation

public final class CopyController {
    public var isEnabled: Bool

    private let frontmostAppProvider: FrontmostAppProviding
    private let textReader: SelectedTextReading
    private let clipboardWriter: ClipboardWriting
    private let permissionChecker: AccessibilityPermissionChecking
    private let selectedTextRetryCount: Int
    private let selectedTextRetryDelayNanoseconds: UInt64
    private let sleep: (UInt64) -> Void

    public init(
        isEnabled: Bool = true,
        frontmostAppProvider: FrontmostAppProviding,
        textReader: SelectedTextReading,
        clipboardWriter: ClipboardWriting,
        permissionChecker: AccessibilityPermissionChecking,
        selectedTextRetryCount: Int = 3,
        selectedTextRetryDelayNanoseconds: UInt64 = 15_000_000,
        sleep: @escaping (UInt64) -> Void = { Thread.sleep(forTimeInterval: TimeInterval($0) / 1_000_000_000) }
    ) {
        self.isEnabled = isEnabled
        self.frontmostAppProvider = frontmostAppProvider
        self.textReader = textReader
        self.clipboardWriter = clipboardWriter
        self.permissionChecker = permissionChecker
        self.selectedTextRetryCount = max(0, selectedTextRetryCount)
        self.selectedTextRetryDelayNanoseconds = selectedTextRetryDelayNanoseconds
        self.sleep = sleep
    }

    @discardableResult
    public func handleCommandC() -> Bool {
        guard isEnabled else {
            return false
        }

        guard permissionChecker.isAccessibilityTrusted(prompt: false) else {
            diagLog("WhatsCopy: Cmd-C seen but Accessibility not trusted")
            return false
        }

        guard let app = frontmostAppProvider.frontmostApp(),
              FrontmostAppDetector.isWhatsApp(app),
              let processIdentifier = app.processIdentifier else {
            return false
        }

        guard let selectedText = selectedTextWithRetries(processIdentifier: processIdentifier) else {
            diagLog("WhatsCopy: Cmd-C in WhatsApp but no selected text found")
            return false
        }
        diagLog("WhatsCopy: copied \(selectedText.count) characters")

        return clipboardWriter.writePlainText(selectedText)
    }

    private func selectedTextWithRetries(processIdentifier: pid_t) -> String? {
        for attempt in 0...selectedTextRetryCount {
            if let selectedText = textReader.selectedTextForFrontmostApplication(
                processIdentifier: processIdentifier
            ),
            !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return selectedText
            }

            if attempt < selectedTextRetryCount {
                sleep(selectedTextRetryDelayNanoseconds)
            }
        }

        return nil
    }
}
