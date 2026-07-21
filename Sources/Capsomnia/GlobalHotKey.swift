import AppKit
import Carbon.HIToolbox

struct ShortcutModifiers: OptionSet, Equatable {
    let rawValue: UInt32

    static let control = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let shift = ShortcutModifiers(rawValue: 1 << 2)
    static let command = ShortcutModifiers(rawValue: 1 << 3)

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var value: ShortcutModifiers = []
        if eventFlags.contains(.control) {
            value.insert(.control)
        }
        if eventFlags.contains(.option) {
            value.insert(.option)
        }
        if eventFlags.contains(.shift) {
            value.insert(.shift)
        }
        if eventFlags.contains(.command) {
            value.insert(.command)
        }
        self = value
    }

    var containsPrimaryModifier: Bool {
        !intersection([.control, .option, .command]).isEmpty
    }

    var carbonValue: UInt32 {
        var value: UInt32 = 0
        if contains(.control) {
            value |= UInt32(controlKey)
        }
        if contains(.option) {
            value |= UInt32(optionKey)
        }
        if contains(.shift) {
            value |= UInt32(shiftKey)
        }
        if contains(.command) {
            value |= UInt32(cmdKey)
        }
        return value
    }

    var displayTokens: [String] {
        var tokens: [String] = []
        if contains(.control) {
            tokens.append("⌃")
        }
        if contains(.option) {
            tokens.append("⌥")
        }
        if contains(.shift) {
            tokens.append("⇧")
        }
        if contains(.command) {
            tokens.append("⌘")
        }
        return tokens
    }
}

struct KeyboardShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: ShortcutModifiers
    let key: String

    init(keyCode: UInt32, modifiers: ShortcutModifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key.uppercased()
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = ShortcutModifiers(eventFlags: flags)
        let keyCode = UInt32(event.keyCode)

        if let functionKey = Self.functionKeyLabel(for: event.keyCode) {
            guard modifiers.containsPrimaryModifier || modifiers == [.shift] else {
                return nil
            }
            self.init(
                keyCode: keyCode,
                modifiers: modifiers,
                key: functionKey
            )
            return
        }

        guard modifiers.containsPrimaryModifier,
              let characters = event.charactersIgnoringModifiers,
              let character = characters.first,
              !character.isWhitespace,
              !character.isNewline else {
            return nil
        }

        self.init(
            keyCode: keyCode,
            modifiers: modifiers,
            key: String(character)
        )
    }

    private static func functionKeyLabel(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        case kVK_F13: "F13"
        case kVK_F14: "F14"
        case kVK_F15: "F15"
        case kVK_F16: "F16"
        case kVK_F17: "F17"
        case kVK_F18: "F18"
        case kVK_F19: "F19"
        case kVK_F20: "F20"
        default: nil
        }
    }

    var displayTokens: [String] {
        modifiers.displayTokens + [key]
    }

    var displayValue: String {
        displayTokens.joined()
    }
}

private func capsomniaGlobalHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<GlobalHotKeyManager>
        .fromOpaque(userData)
        .takeUnretainedValue()
    return manager.handle(event: event)
}

final class GlobalHotKeyManager {
    static let hotKeyID = EventHotKeyID(
        signature: 0x4350534D,
        id: 1
    )

    private var eventHandlerRef: EventHandlerRef?
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandlerStatus: OSStatus = OSStatus(eventNotHandledErr)
    private(set) var activeShortcut: KeyboardShortcut?
    var onTrigger: (() -> Void)?

    init() {
        installEventHandler()
    }

    deinit {
        unregisterCurrentShortcut()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func replaceShortcut(with shortcut: KeyboardShortcut?) -> OSStatus {
        precondition(Thread.isMainThread)

        if shortcut == activeShortcut {
            return noErr
        }

        let previousShortcut = activeShortcut
        unregisterCurrentShortcut()

        guard let shortcut else {
            return noErr
        }

        let status = register(shortcut)
        guard status != noErr else {
            return noErr
        }

        if let previousShortcut {
            _ = register(previousShortcut)
        }
        return status
    }

    func suspend() {
        precondition(Thread.isMainThread)
        unregisterCurrentShortcut()
    }

    fileprivate func handle(event: EventRef) -> OSStatus {
        var receivedID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &receivedID
        )
        guard status == noErr,
              receivedID.signature == Self.hotKeyID.signature,
              receivedID.id == Self.hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }

        onTrigger?()
        return noErr
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        eventHandlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            capsomniaGlobalHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func register(_ shortcut: KeyboardShortcut) -> OSStatus {
        guard eventHandlerStatus == noErr else {
            return eventHandlerStatus
        }

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers.carbonValue,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &reference
        )
        guard status == noErr, let reference else {
            return status
        }

        eventHotKeyRef = reference
        activeShortcut = shortcut
        return noErr
    }

    private func unregisterCurrentShortcut() {
        if let eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
        }
        eventHotKeyRef = nil
        activeShortcut = nil
    }
}
