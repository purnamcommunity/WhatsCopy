import AppKit

public struct AppIdentity: Equatable {
    public let localizedName: String?
    public let bundleIdentifier: String?
    public let processIdentifier: pid_t?

    public init(
        localizedName: String?,
        bundleIdentifier: String?,
        processIdentifier: pid_t? = nil
    ) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

public protocol FrontmostAppProviding {
    func frontmostApp() -> AppIdentity?
}

public struct FrontmostAppDetector: FrontmostAppProviding {
    public static let knownWhatsAppBundleIdentifiers: Set<String> = [
        "net.whatsapp.WhatsApp",
        "com.whatsapp.WhatsApp",
        "com.facebook.archon"
    ]

    public init() {}

    public func frontmostApp() -> AppIdentity? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return AppIdentity(
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            processIdentifier: application.processIdentifier
        )
    }

    public static func isWhatsApp(_ app: AppIdentity) -> Bool {
        if let bundleIdentifier = app.bundleIdentifier,
           knownWhatsAppBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }

        if let localizedName = app.localizedName?.lowercased(),
           localizedName.contains("whatsapp") {
            return true
        }

        return false
    }
}
