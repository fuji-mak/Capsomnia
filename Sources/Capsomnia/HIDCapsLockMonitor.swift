import CoreGraphics
import Foundation
import IOKit
import IOKit.hid

/// Tracks key presses, not the Caps Lock LED or modifier state.
struct HIDCapsLockPressTracker {
    private var pressedDevices: Set<UInt64> = []

    mutating func handle(
        deviceID: UInt64,
        usagePage: UInt32,
        usage: UInt32,
        value: Int
    ) -> Bool {
        guard usagePage == 0x07, usage == 0x39 else { return false }
        switch value {
        case 1:
            return pressedDevices.insert(deviceID).inserted
        case 0:
            pressedDevices.remove(deviceID)
            return false
        default:
            return false
        }
    }

    mutating func removeDevice(_ deviceID: UInt64) {
        pressedDevices.remove(deviceID)
    }
}

/// Optional, non-exclusive observation of Caps Lock key input. It never writes
/// keyboard state or consumes an event, and does not request permission.
final class HIDCapsLockMonitor {
    enum State {
        case inactive, active, permissionRequired, unavailable
    }

    var onPress: (() -> Void)?
    private(set) var state: State = .inactive
    private var manager: IOHIDManager?
    private var tracker = HIDCapsLockPressTracker()
    private var devices: Set<UInt64> = []

    var isActive: Bool { state == .active && !devices.isEmpty }

    deinit { stop() }

    @discardableResult
    func start() -> State {
        guard CGPreflightListenEventAccess() else {
            stop()
            state = .permissionRequired
            return state
        }
        if manager != nil { return state }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: 1,
            kIOHIDDeviceUsageKey: 6
        ] as CFDictionary)
        IOHIDManagerSetInputValueMatching(manager, [
            kIOHIDElementUsagePageKey: 0x07,
            kIOHIDElementUsageKey: 0x39
        ] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<HIDCapsLockMonitor>.fromOpaque(context).takeUnretainedValue()
                .handle(value)
        }, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<HIDCapsLockMonitor>.fromOpaque(context).takeUnretainedValue()
                .addDevice(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context, let id = HIDCapsLockMonitor.deviceID(device) else { return }
            let monitor = Unmanaged<HIDCapsLockMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.devices.remove(id)
            monitor.tracker.removeDevice(id)
        }, context)
        self.manager = manager
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            stop()
            state = .unavailable
            return state
        }
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            devices.forEach(addDevice)
        }
        state = .active
        return state
    }

    func stop() {
        if let manager {
            IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        devices.removeAll()
        tracker = HIDCapsLockPressTracker()
        state = .inactive
    }

    private func addDevice(_ device: IOHIDDevice) {
        guard let id = Self.deviceID(device),
              let elements = IOHIDDeviceCopyMatchingElements(device, [
                kIOHIDElementUsagePageKey: 0x07,
                kIOHIDElementUsageKey: 0x39
              ] as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement],
              !elements.isEmpty else { return }
        devices.insert(id)
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        guard let id = Self.deviceID(device) else { return }
        if tracker.handle(
            deviceID: id,
            usagePage: IOHIDElementGetUsagePage(element),
            usage: IOHIDElementGetUsage(element),
            value: IOHIDValueGetIntegerValue(value)
        ) {
            onPress?()
        }
    }

    private static func deviceID(_ device: IOHIDDevice) -> UInt64? {
        var id: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == KERN_SUCCESS else {
            return nil
        }
        return id
    }
}
