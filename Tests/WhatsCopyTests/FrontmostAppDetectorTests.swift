import XCTest
@testable import WhatsCopy

final class FrontmostAppDetectorTests: XCTestCase {
    func testMatchesKnownWhatsAppBundleIdentifier() {
        let app = AppIdentity(
            localizedName: nil,
            bundleIdentifier: "net.whatsapp.WhatsApp"
        )

        XCTAssertTrue(FrontmostAppDetector.isWhatsApp(app))
    }

    func testMatchesLocalizedNameContainingWhatsApp() {
        let app = AppIdentity(
            localizedName: "WhatsApp Business",
            bundleIdentifier: "unknown.bundle"
        )

        XCTAssertTrue(FrontmostAppDetector.isWhatsApp(app))
    }

    func testRejectsNonWhatsAppApplication() {
        let app = AppIdentity(
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertFalse(FrontmostAppDetector.isWhatsApp(app))
    }
}
