import AppKit
import SummonKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LauncherPanelController: NSObject {
    let model: LauncherModel
    private let panel: LauncherPanel
    private var eventMonitor: Any?

    override init() {
        model = LauncherModel()
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: LauncherView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect

        model.onRequestClose = { [weak self] in
            self?.hide()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        model.prepareForDisplay()
        centerOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        startEventMonitor()
        DispatchQueue.main.async { [weak self] in
            self?.focusSearchField()
        }
    }

    func hide() {
        stopEventMonitor()
        panel.orderOut(nil)
    }

    private func centerOnActiveScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 80
        )
        panel.setFrameOrigin(origin)
    }

    private func focusSearchField() {
        guard let content = panel.contentView else { return }
        if let field = firstTextField(in: content) {
            panel.makeFirstResponder(field)
        }
    }

    private func firstTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable {
            return field
        }
        for subview in view.subviews {
            if let field = firstTextField(in: subview) {
                return field
            }
        }
        return nil
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let command = LauncherKeyBinding.resolve(event, tabModifier: model.tabModifier) else {
            return false
        }
        switch command {
        case .selectTab(let index):
            model.selectTab(at: index)
        case .adjacentTab(let delta):
            model.selectAdjacentTab(delta: delta)
        case .hide:
            hide()
        case .confirm:
            model.confirm()
        case .moveSelection(let offset):
            model.moveSelection(offset: offset)
        }
        return true
    }

}

enum LauncherKeyBinding: Equatable {
    case selectTab(Int)
    case adjacentTab(Int)
    case hide
    case confirm
    case moveSelection(Int)

    static func resolve(_ event: NSEvent, tabModifier: Hotkey.Modifier) -> LauncherKeyBinding? {
        if let digit = tabDigit(from: event, tabModifier: tabModifier) {
            return .selectTab(digit - 1)
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        switch event.keyCode {
        case 53: // escape
            return .hide
        case 36, 76: // return / keypad enter
            return .confirm
        case 125: // down
            return .moveSelection(1)
        case 126: // up
            return .moveSelection(-1)
        case 123 where flags.isEmpty: // left
            return .adjacentTab(-1)
        case 124 where flags.isEmpty: // right
            return .adjacentTab(1)
        default:
            return nil
        }
    }

    private static func tabDigit(from event: NSEvent, tabModifier: Hotkey.Modifier) -> Int? {
        let needed = nsModifierFlags(tabModifier)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        guard flags == needed else { return nil }
        guard let chars = event.charactersIgnoringModifiers, chars.count == 1,
              let value = Int(chars), (1...9).contains(value)
        else {
            return nil
        }
        return value
    }

    private static func nsModifierFlags(_ modifiers: Hotkey.Modifier) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }
}
