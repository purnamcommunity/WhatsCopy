import XCTest
@testable import WhatsCopy

final class CopyControllerTests: XCTestCase {
    func testDisabledControllerPassesEventThrough() {
        let clipboard = ClipboardSpy()
        let controller = makeController(
            isEnabled: false,
            app: whatsappApp(),
            selectedText: "hello",
            clipboard: clipboard
        )

        XCTAssertFalse(controller.handleCommandC())
        XCTAssertNil(clipboard.lastWrittenText)
    }

    func testNonWhatsAppFrontmostAppPassesEventThrough() {
        let clipboard = ClipboardSpy()
        let controller = makeController(
            app: AppIdentity(
                localizedName: "TextEdit",
                bundleIdentifier: "com.apple.TextEdit",
                processIdentifier: 42
            ),
            selectedText: "hello",
            clipboard: clipboard
        )

        XCTAssertFalse(controller.handleCommandC())
        XCTAssertNil(clipboard.lastWrittenText)
    }

    func testMissingPermissionPassesEventThrough() {
        let clipboard = ClipboardSpy()
        let controller = makeController(
            app: whatsappApp(),
            selectedText: "hello",
            clipboard: clipboard,
            isTrusted: false
        )

        XCTAssertFalse(controller.handleCommandC())
        XCTAssertNil(clipboard.lastWrittenText)
    }

    func testEmptySelectionPassesEventThrough() {
        let clipboard = ClipboardSpy()
        let controller = makeController(
            app: whatsappApp(),
            selectedText: "   \n",
            clipboard: clipboard
        )

        XCTAssertFalse(controller.handleCommandC())
        XCTAssertNil(clipboard.lastWrittenText)
    }

    func testWhatsAppSelectionIsCopiedAndEventIsSwallowed() {
        let clipboard = ClipboardSpy()
        let controller = makeController(
            app: whatsappApp(),
            selectedText: "selected message",
            clipboard: clipboard
        )

        XCTAssertTrue(controller.handleCommandC())
        XCTAssertEqual(clipboard.lastWrittenText, "selected message")
    }

    func testTransientSelectedTextMissIsRetried() {
        let clipboard = ClipboardSpy()
        let textReader = SequencedTextReaderStub(selectedTexts: [nil, "selected after retry"])
        var sleptNanoseconds: [UInt64] = []
        let controller = makeController(
            app: whatsappApp(),
            textReader: textReader,
            clipboard: clipboard,
            selectedTextRetryCount: 3,
            selectedTextRetryDelayNanoseconds: 10,
            sleep: { sleptNanoseconds.append($0) }
        )

        XCTAssertTrue(controller.handleCommandC())
        XCTAssertEqual(clipboard.lastWrittenText, "selected after retry")
        XCTAssertEqual(textReader.callCount, 2)
        XCTAssertEqual(sleptNanoseconds, [10])
    }

    func testRetriesAreBoundedWhenSelectionNeverAppears() {
        let clipboard = ClipboardSpy()
        let textReader = SequencedTextReaderStub(selectedTexts: [nil, nil, nil, nil])
        var sleptNanoseconds: [UInt64] = []
        let controller = makeController(
            app: whatsappApp(),
            textReader: textReader,
            clipboard: clipboard,
            selectedTextRetryCount: 3,
            selectedTextRetryDelayNanoseconds: 10,
            sleep: { sleptNanoseconds.append($0) }
        )

        XCTAssertFalse(controller.handleCommandC())
        XCTAssertNil(clipboard.lastWrittenText)
        XCTAssertEqual(textReader.callCount, 4)
        XCTAssertEqual(sleptNanoseconds, [10, 10, 10])
    }

    private func makeController(
        isEnabled: Bool = true,
        app: AppIdentity?,
        selectedText: String?,
        clipboard: ClipboardSpy,
        isTrusted: Bool = true
    ) -> CopyController {
        makeController(
            isEnabled: isEnabled,
            app: app,
            textReader: TextReaderStub(selectedText: selectedText),
            clipboard: clipboard,
            isTrusted: isTrusted
        )
    }

    private func makeController(
        isEnabled: Bool = true,
        app: AppIdentity?,
        textReader: SelectedTextReading,
        clipboard: ClipboardSpy,
        isTrusted: Bool = true,
        selectedTextRetryCount: Int = 3,
        selectedTextRetryDelayNanoseconds: UInt64 = 15_000_000,
        sleep: @escaping (UInt64) -> Void = { _ in }
    ) -> CopyController {
        CopyController(
            isEnabled: isEnabled,
            frontmostAppProvider: FrontmostAppProviderStub(app: app),
            textReader: textReader,
            clipboardWriter: clipboard,
            permissionChecker: PermissionCheckerStub(isTrusted: isTrusted),
            selectedTextRetryCount: selectedTextRetryCount,
            selectedTextRetryDelayNanoseconds: selectedTextRetryDelayNanoseconds,
            sleep: sleep
        )
    }

    private func whatsappApp() -> AppIdentity {
        AppIdentity(
            localizedName: "WhatsApp",
            bundleIdentifier: "net.whatsapp.WhatsApp",
            processIdentifier: 42
        )
    }
}

private struct FrontmostAppProviderStub: FrontmostAppProviding {
    let app: AppIdentity?

    func frontmostApp() -> AppIdentity? {
        app
    }
}

private struct TextReaderStub: SelectedTextReading {
    let selectedText: String?

    func selectedTextForFrontmostApplication(processIdentifier: pid_t) -> String? {
        selectedText
    }
}

private final class SequencedTextReaderStub: SelectedTextReading {
    private let selectedTexts: [String?]
    private(set) var callCount = 0

    init(selectedTexts: [String?]) {
        self.selectedTexts = selectedTexts
    }

    func selectedTextForFrontmostApplication(processIdentifier: pid_t) -> String? {
        defer { callCount += 1 }

        guard callCount < selectedTexts.count else {
            return selectedTexts.last ?? nil
        }

        return selectedTexts[callCount]
    }
}

private final class ClipboardSpy: ClipboardWriting {
    private(set) var lastWrittenText: String?

    func writePlainText(_ text: String) -> Bool {
        lastWrittenText = text
        return true
    }
}

private struct PermissionCheckerStub: AccessibilityPermissionChecking {
    let isTrusted: Bool

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        isTrusted
    }
}
