import AppKit

public protocol ClipboardWriting {
    @discardableResult
    func writePlainText(_ text: String) -> Bool
}

public final class ClipboardWriter: ClipboardWriting {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    public func writePlainText(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
