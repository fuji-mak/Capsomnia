import ApplicationServices
import CoreGraphics
import Foundation

enum DedicatedCapsLockEventPolicy {
    static let capsLockKeyCode: Int64 = 57

    static func sanitizedFlags(_ flags: CGEventFlags) -> CGEventFlags {
        var sanitized = flags
        sanitized.remove(.maskAlphaShift)
        return sanitized
    }

    static func shouldSuppress(eventType: CGEventType, keyCode: Int64) -> Bool {
        eventType == .flagsChanged && keyCode == capsLockKeyCode
    }
}

enum DedicatedCapsLockReadinessPolicy {
    static func shouldHonorCapsLock(dedicatedModeEnabled: Bool, filterActive: Bool) -> Bool {
        !dedicatedModeEnabled || filterActive
    }
}

enum DedicatedCapsLockFilterState: Equatable {
    case inactive
    case active
    case permissionRequired
    case unavailable
}

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

final class DedicatedCapsLockFilter {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var state: DedicatedCapsLockFilterState = .inactive

    var isActive: Bool {
        guard state == .active, let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    deinit {
        stop()
    }

    @discardableResult
    func start(promptForPermission: Bool) -> DedicatedCapsLockFilterState {
        if isActive {
            return .active
        }

        stop()

        guard AccessibilityPermission.isTrusted(prompt: promptForPermission) else {
            state = .permissionRequired
            return state
        }

        let eventMask = mask(for: [.flagsChanged, .keyDown, .keyUp])
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: dedicatedCapsLockEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            state = .unavailable
            return state
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            state = .unavailable
            return state
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        guard CGEvent.tapIsEnabled(tap: eventTap) else {
            stop()
            state = .unavailable
            return state
        }

        state = .active
        return state
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        state = .inactive
    }

    fileprivate func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            guard let eventTap else {
                state = .unavailable
                return Unmanaged.passUnretained(event)
            }

            CGEvent.tapEnable(tap: eventTap, enable: true)
            state = CGEvent.tapIsEnabled(tap: eventTap) ? .active : .unavailable
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        event.flags = DedicatedCapsLockEventPolicy.sanitizedFlags(event.flags)

        if DedicatedCapsLockEventPolicy.shouldSuppress(eventType: type, keyCode: keyCode) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func mask(for eventTypes: [CGEventType]) -> CGEventMask {
        eventTypes.reduce(0) { result, eventType in
            result | (CGEventMask(1) << eventType.rawValue)
        }
    }
}

private let dedicatedCapsLockEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let filter = Unmanaged<DedicatedCapsLockFilter>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return filter.handle(type: type, event: event)
}
