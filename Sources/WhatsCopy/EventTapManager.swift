import ApplicationServices
import Foundation

public final class EventTapManager {
    public var isEnabled: Bool = true

    private let commandCHandler: () -> Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init(commandCHandler: @escaping () -> Bool) {
        self.commandCHandler = commandCHandler
    }

    public func start() {
        guard eventTap == nil else {
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: EventTapManager.eventTapCallback,
            userInfo: userInfo
        ) else {
            diagLog("WhatsCopy: event tap creation failed (Accessibility not granted?)")
            return
        }
        diagLog("WhatsCopy: event tap started")

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        eventTap = nil
        runLoopSource = nil
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            guard isEnabled, CopyShortcutMatcher.isCommandC(event) else {
                return Unmanaged.passUnretained(event)
            }

            return commandCHandler() ? nil : Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, eventType, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<EventTapManager>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        return manager.handle(eventType: eventType, event: event)
    }
}

public enum CopyShortcutMatcher {
    private static let cKeyCode: Int64 = 8

    public static func isCommandC(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == cKeyCode else {
            return false
        }

        let flags = event.flags
        let disallowedModifiers: CGEventFlags = [.maskAlternate, .maskControl, .maskShift]
        return flags.contains(.maskCommand) && flags.intersection(disallowedModifiers).isEmpty
    }
}
