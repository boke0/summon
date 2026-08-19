import Carbon
import Foundation

final class HotkeyCenter: @unchecked Sendable {
    static let shared = HotkeyCenter()

    var onPressed: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: 0x73756D31, id: 1)

    private init() {}

    func register(keyCode: UInt32, carbonModifiers: UInt32) {
        unregisterHotKey()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status != noErr {
            NSLog("summon: RegisterEventHotKey failed (%d)", status)
            return
        }
        hotKeyRef = ref
    }

    func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            summonHotkeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &ref
        )
        if status != noErr {
            NSLog("summon: InstallEventHandler failed (%d)", status)
            return
        }
        handlerRef = ref
    }

    fileprivate func handlePress() {
        DispatchQueue.main.async { [weak self] in
            self?.onPressed?()
        }
    }
}

private func summonHotkeyHandler(
    _: EventHandlerCallRef?,
    event _: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue().handlePress()
    return noErr
}
