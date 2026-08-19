import AppKit
import ApplicationServices
import SummonKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var panelController: LauncherPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = LauncherPanelController()
        setupStatusItem()
        registerHotkeyFromConfig()
        HotkeyCenter.shared.onPressed = { [weak self] in
            self?.handleHotkey()
        }
        promptAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyCenter.shared.unregisterHotKey()
    }

    func applicationDidResignActive(_ notification: Notification) {
        panelController?.hide()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "summon")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open", action: #selector(openLauncher), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Summon", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func handleHotkey() {
        panelController?.toggle()
        registerHotkeyFromConfig()
    }

    @objc private func openLauncher() {
        panelController?.model.reload()
        registerHotkeyFromConfig()
        panelController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func promptAccessibilityIfNeeded() {
        if AXIsProcessTrusted() { return }

        let defaults = UserDefaults.standard
        let promptedKey = "summon.didPromptAccessibility"
        if defaults.bool(forKey: promptedKey) { return }
        defaults.set(true, forKey: promptedKey)

        // String matches kAXTrustedCheckOptionPrompt (CF global is not Swift 6-safe here).
        _ = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )

        let settingsURLs = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for string in settingsURLs {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                break
            }
        }
    }

    private func registerHotkeyFromConfig() {
        let hotkey = panelController?.model.parsedHotkey
            ?? ((try? HotkeyParser.parse("cmd+d")) ?? Hotkey(
                modifiers: .command,
                key: Hotkey.Key(name: "d", carbonKeyCode: 0x02)
            ))
        HotkeyCenter.shared.register(
            keyCode: hotkey.carbonKeyCode,
            carbonModifiers: hotkey.carbonModifiers
        )
    }
}
