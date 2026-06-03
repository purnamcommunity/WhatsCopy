import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionManager: PermissionManager
    private let launchAtLoginManager: LaunchAtLoginManaging
    private let eventTapManager: EventTapManager
    private let copyController: CopyController
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?

    public override convenience init() {
        let permissionManager = PermissionManager()
        let detector = FrontmostAppDetector()
        let reader = AccessibilityTextReader()
        let clipboardWriter = ClipboardWriter()
        let launchAtLoginManager = LaunchAtLoginManager()
        let copyController = CopyController(
            frontmostAppProvider: detector,
            textReader: reader,
            clipboardWriter: clipboardWriter,
            permissionChecker: permissionManager
        )
        let eventTapManager = EventTapManager {
            copyController.handleCommandC()
        }

        self.init(
            permissionManager: permissionManager,
            launchAtLoginManager: launchAtLoginManager,
            eventTapManager: eventTapManager,
            copyController: copyController
        )
    }

    init(
        permissionManager: PermissionManager,
        launchAtLoginManager: LaunchAtLoginManaging,
        eventTapManager: EventTapManager,
        copyController: CopyController
    ) {
        self.permissionManager = permissionManager
        self.launchAtLoginManager = launchAtLoginManager
        self.eventTapManager = eventTapManager
        self.copyController = copyController
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        eventTapManager.start()

        if !permissionManager.isAccessibilityTrusted(prompt: false) {
            permissionManager.showPermissionInstructions()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        eventTapManager.stop()
    }

    private func configureMenu() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let logo = Self.logoImage() {
            logo.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = logo
        } else {
            statusItem.button?.title = "⌘C"
        }
        statusItem.button?.toolTip = "WhatsCopy"

        let menu = NSMenu()
        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = copyController.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let permissionItem = NSMenuItem(
            title: "Check Accessibility Permission",
            action: #selector(checkAccessibilityPermission),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        let openAccessibilitySettingsItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        openAccessibilitySettingsItem.target = self
        menu.addItem(openAccessibilitySettingsItem)

        menu.addItem(.separator())

        let versionItem = NSMenuItem(
            title: Self.versionMenuTitle(),
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let aboutItem = NSMenuItem(
            title: "About WhatsCopy",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
        self.enabledMenuItem = enabledItem
        self.launchAtLoginMenuItem = launchAtLoginItem
    }

    private static func logoImage() -> NSImage? {
        if let url = Bundle.module.url(
            forResource: "whatscopy-logo",
            withExtension: "png",
            subdirectory: "Resources"
        ) {
            return NSImage(contentsOf: url)
        }

        if let url = Bundle.main.url(forResource: "whatscopy-logo", withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        return nil
    }

    private static func versionMenuTitle() -> String {
        let infoDictionary = Bundle.main.infoDictionary ?? [:]
        let version = infoDictionary["CFBundleShortVersionString"] as? String
        let build = infoDictionary["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        default:
            return "Version 0.1.0"
        }
    }

    @objc private func toggleEnabled() {
        copyController.isEnabled.toggle()
        eventTapManager.isEnabled = copyController.isEnabled
        enabledMenuItem?.state = copyController.isEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = !launchAtLoginManager.isEnabled

        do {
            try launchAtLoginManager.setEnabled(newValue)
            launchAtLoginMenuItem?.state = launchAtLoginManager.isEnabled ? .on : .off
        } catch {
            showLaunchAtLoginError(error)
            launchAtLoginMenuItem?.state = launchAtLoginManager.isEnabled ? .on : .off
        }
    }

    @objc private func checkAccessibilityPermission() {
        if permissionManager.isAccessibilityTrusted(prompt: true) {
            permissionManager.showTrustedConfirmation()
        } else {
            permissionManager.showPermissionInstructions()
        }
    }

    @objc private func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WhatsCopy"
        alert.informativeText = """
        Restore Command-C for selected text in WhatsApp for Mac.

        Privacy-first, unofficial, open-source utility. Not affiliated with WhatsApp or Meta.
        """
        alert.icon = Self.logoImage()
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
