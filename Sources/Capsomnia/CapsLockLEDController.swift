import Foundation
import IOKit.hid

struct CapsLockLEDWriteResult {
    let matchedDevices: Int
    let matchedElements: Int
    let successfulWrites: Int
    let errorCodes: [IOReturn]

    var succeeded: Bool {
        matchedElements > 0 && successfulWrites == matchedElements && errorCodes.isEmpty
    }

    var logDescription: String {
        let errors = errorCodes
            .map { String(format: "0x%08x", UInt32(bitPattern: $0)) }
            .joined(separator: ",")
        return "devices=\(matchedDevices) elements=\(matchedElements) writes=\(successfulWrites) errors=\(errors.isEmpty ? "none" : errors)"
    }

    var failureSignature: String {
        "devices=\(matchedDevices);elements=\(matchedElements);writes=\(successfulWrites);errors=\(errorCodes)"
    }
}

protocol CapsLockLEDWriting: AnyObject {
    func writeCapsLockLED(enabled: Bool) -> CapsLockLEDWriteResult
}

/// Writes the standard HID Caps Lock LED output without changing the logical
/// Caps Lock modifier state. That separation is essential for users who mapped
/// the physical Caps Lock key to Control: synthesizing alphaShift would alter
/// typing behavior, while writing usage page 0x08 / usage 0x02 changes only the
/// indicator exposed by the keyboard.
final class HIDCapsLockLEDWriter: CapsLockLEDWriting {
    private let manager: IOHIDManager
    private var isOpen = false

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let keyboardMatch = [
            kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Keyboard)
        ] as CFDictionary
        IOHIDManagerSetDeviceMatching(manager, keyboardMatch)
    }

    deinit {
        if isOpen {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    func writeCapsLockLED(enabled: Bool) -> CapsLockLEDWriteResult {
        if !isOpen {
            let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            guard openStatus == kIOReturnSuccess else {
                return CapsLockLEDWriteResult(
                    matchedDevices: 0,
                    matchedElements: 0,
                    successfulWrites: 0,
                    errorCodes: [openStatus]
                )
            }
            isOpen = true
        }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return CapsLockLEDWriteResult(
                matchedDevices: 0,
                matchedElements: 0,
                successfulWrites: 0,
                errorCodes: []
            )
        }

        let devices = Array(deviceSet)
        let builtInDevices = devices.filter(isBuiltIn)

        // Prefer the built-in keyboard because Capsomnia's physical switch is
        // the MacBook key itself. If a desktop Mac or an older driver does not
        // expose Built-In, fall back to all matching keyboards instead of
        // silently disabling the feature.
        let targetDevices = builtInDevices.isEmpty ? devices : builtInDevices
        let elementMatch = [
            kIOHIDElementUsagePageKey: Int(kHIDPage_LEDs),
            kIOHIDElementUsageKey: Int(kHIDUsage_LED_CapsLock)
        ] as CFDictionary

        var matchedElements = 0
        var successfulWrites = 0
        var errors: [IOReturn] = []

        for device in targetDevices {
            guard let elements = IOHIDDeviceCopyMatchingElements(
                device,
                elementMatch,
                IOOptionBits(kIOHIDOptionsTypeNone)
            ) as? [IOHIDElement] else {
                continue
            }

            for element in elements where IOHIDElementGetType(element) == kIOHIDElementTypeOutput {
                matchedElements += 1
                let value = IOHIDValueCreateWithIntegerValue(
                    kCFAllocatorDefault,
                    element,
                    mach_absolute_time(),
                    enabled ? 1 : 0
                )
                let status = IOHIDDeviceSetValue(device, element, value)
                if status == kIOReturnSuccess {
                    successfulWrites += 1
                } else {
                    errors.append(status)
                }
            }
        }

        return CapsLockLEDWriteResult(
            matchedDevices: targetDevices.count,
            matchedElements: matchedElements,
            successfulWrites: successfulWrites,
            errorCodes: errors
        )
    }

    private func isBuiltIn(_ device: IOHIDDevice) -> Bool {
        guard let property = IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) else {
            return false
        }
        return (property as? NSNumber)?.boolValue == true
    }
}

/// Retry state is kept separate from Dispatch so the "stop after three equal
/// failures" rule and jitter range can be verified without touching hardware.
struct CapsLockLEDRetryPolicy {
    private(set) var consecutiveFailures = 0
    let baseDelay: TimeInterval

    init(baseDelay: TimeInterval = 0.5) {
        self.baseDelay = baseDelay
    }

    mutating func reset() {
        consecutiveFailures = 0
    }

    mutating func delayAfterFailure(randomUnit: Double) -> TimeInterval? {
        consecutiveFailures += 1
        guard consecutiveFailures < 3 else { return nil }

        // Equal jitter avoids a zero-delay retry while still preventing several
        // processes or devices from retrying in lockstep after wake or reconnect.
        let upperBound = baseDelay * pow(2, Double(consecutiveFailures - 1))
        let lowerBound = upperBound / 2
        let unit = min(max(randomUnit, 0), 1)
        return lowerBound + ((upperBound - lowerBound) * unit)
    }
}

/// Serializes synchronous HID output away from the main thread and coalesces
/// repeated confirmations of the same state. A changed user choice gets a fresh
/// retry budget; an unchanged failing request stops after three attempts until
/// a different requested state or physical Caps Lock handoff provides new
/// evidence to retry.
final class CapsLockLEDController {
    typealias Logger = (String) -> Void

    private let writer: CapsLockLEDWriting
    private let logger: Logger
    private let queue = DispatchQueue(label: "com.github.fuji-mak.capsomnia.caps-lock-led")
    private var requestedState: Bool?
    private var successfullyWrittenState: Bool?
    private var haltedState: Bool?
    private var lastFailureSignature: String?
    private var retryPolicy = CapsLockLEDRetryPolicy()
    private var requestGeneration = 0

    init(
        writer: CapsLockLEDWriting = HIDCapsLockLEDWriter(),
        retryPolicy: CapsLockLEDRetryPolicy = CapsLockLEDRetryPolicy(),
        logger: @escaping Logger
    ) {
        self.writer = writer
        self.retryPolicy = retryPolicy
        self.logger = logger
    }

    func synchronize(
        enabled: Bool,
        reason: String,
        environmentChanged: Bool = false
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            let stateChanged = self.requestedState != enabled
            if stateChanged || environmentChanged {
                self.requestGeneration += 1
                self.retryPolicy.reset()
                self.successfullyWrittenState = nil
                self.haltedState = nil
                self.lastFailureSignature = nil
            }
            self.requestedState = enabled

            guard self.successfullyWrittenState != enabled,
                  self.haltedState != enabled else {
                return
            }
            self.attemptWrite(enabled: enabled, reason: reason, generation: self.requestGeneration)
        }
    }

    /// App termination cannot wait for an asynchronous retry. Invalidate queued
    /// work, wait for any in-flight HID report, and make one final best-effort
    /// restoration to the actual macOS Caps Lock state before the process exits.
    func restoreImmediately(enabled: Bool, reason: String) {
        queue.sync {
            requestGeneration += 1
            requestedState = enabled
            retryPolicy.reset()
            haltedState = nil
            lastFailureSignature = nil
            let result = writer.writeCapsLockLED(enabled: enabled)
            logger("\(reason) capslock_led_restore=\(enabled ? "on" : "off") \(result.logDescription)")
        }
    }

    private func attemptWrite(enabled: Bool, reason: String, generation: Int) {
        let result = writer.writeCapsLockLED(enabled: enabled)
        guard generation == requestGeneration, requestedState == enabled else { return }

        if result.succeeded {
            retryPolicy.reset()
            successfullyWrittenState = enabled
            haltedState = nil
            lastFailureSignature = nil
            logger("\(reason) capslock_led=\(enabled ? "on" : "off") \(result.logDescription)")
            return
        }

        // Only identical failures count toward the three-attempt cutoff. A
        // different device/error signature is new diagnostic evidence, so it
        // starts a fresh bounded retry sequence rather than inheriting the old
        // failure's budget.
        if lastFailureSignature != result.failureSignature {
            retryPolicy.reset()
            lastFailureSignature = result.failureSignature
        }

        guard let delay = retryPolicy.delayAfterFailure(randomUnit: Double.random(in: 0...1)) else {
            haltedState = enabled
            logger("\(reason) capslock_led_failed attempts=3 action=stopped \(result.logDescription)")
            return
        }

        logger(
            "\(reason) capslock_led_failed attempt=\(retryPolicy.consecutiveFailures) "
                + "retry_ms=\(Int(delay * 1_000)) \(result.logDescription)"
        )
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  generation == self.requestGeneration,
                  self.requestedState == enabled else {
                return
            }
            self.attemptWrite(enabled: enabled, reason: reason, generation: generation)
        }
    }
}
