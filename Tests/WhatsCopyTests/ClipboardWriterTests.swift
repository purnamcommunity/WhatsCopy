import AppKit
import XCTest
@testable import WhatsCopy

final class ClipboardWriterTests: XCTestCase {
    func testWritePlainTextStoresStringOnPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        XCTAssertTrue(writer.writePlainText("Selected WhatsApp text"))
        XCTAssertEqual(pasteboard.string(forType: .string), "Selected WhatsApp text")
    }
}
