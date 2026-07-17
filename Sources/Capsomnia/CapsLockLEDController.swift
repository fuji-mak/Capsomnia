import CoreFoundation
import Foundation
import IOKit.hidsystem

// The public Swift module omits this exported constructor. A Passive client can
// access service properties without opening a keyboard device or reading input.
@_silgen_name("IOHIDEventSystemClientCreateWithType")
private func createEventSystemClient(
    _ allocator: CFAllocator?,
    _ clientType: UInt32,
    _ attributes: CFDictionary?
) -> IOHIDEventSystemClient

enum CapsLockLEDMode: Equatable {
    case on
    case off
    case automatic

    var eventSystemValue: String {
        switch self {
        case .on: "On"
        case .off: "Off"
        case .automatic: "Auto"
        }
    }
}

struct CapsLockLEDUpdateResult: Equatable {
    let matchedKeyboards: Int
    let targetedKeyboards: Int
    let successfulWrites: Int

    var logDescription: String {
        "keyboards=\(matchedKeyboards) targets=\(targetedKeyboards) writes=\(successfulWrites)"
    }
}

protocol CapsLockLEDWriting: AnyObject {
    func setMode(_ mode: CapsLockLEDMode) throws -> CapsLockLEDUpdateResult
    func isModeApplied(_ mode: CapsLockLEDMode) throws -> Bool
}

enum CapsLockLEDControlError: LocalizedError {
    case servicesUnavailable
    case keyboardNotFound
    case writeRejected(targetCount: Int, successfulWrites: Int)

    var errorDescription: String? {
        switch self {
        case .servicesUnavailable:
            "macOS did not expose HID event-system services"
        case .keyboardNotFound:
            "no keyboard service was found"
        case let .writeRejected(targetCount, successfulWrites):
            "macOS accepted \(successfulWrites) of \(targetCount) Caps Lock LED writes"
        }
    }
}

/// Controls only the indicator exposed by macOS's keyboard event-system filter.
///
/// Unlike opening an IOHIDDevice, this path does not read keyboard events and
/// therefore does not require Input Monitoring. `HIDCapsLockLED` is unsupported
/// SPI, so all private keys and values stay isolated in this type.
final class EventSystemCapsLockLEDWriter: CapsLockLEDWriting {
    private static let capsLockLEDKey = "HIDCapsLockLED" as CFString
    private static let builtInKey = "Built-In" as CFString
    private static let passiveClientType: UInt32 = 2
    private static let genericDesktopUsagePage: UInt32 = 0x01
    private static let keyboardUsage: UInt32 = 0x06

    // Keeping one client avoids rebuilding the event-system connection on every
    // 10 ms state check. It does not reserve the LED's last-writer-wins value.
    private let client: IOHIDEventSystemClient

    init() {
        client = createEventSystemClient(
            kCFAllocatorDefault,
            Self.passiveClientType,
            nil
        )
    }

    func setMode(_ mode: CapsLockLEDMode) throws -> CapsLockLEDUpdateResult {
        let selection = try targetKeyboards()
        let value = mode.eventSystemValue as NSString
        let successfulWrites = selection.targets.reduce(into: 0) { count, service in
            if IOHIDServiceClientSetProperty(service, Self.capsLockLEDKey, value) {
                count += 1
            }
        }

        // A partial write would otherwise be observed as a mismatch every 10 ms
        // and create an unbounded repair loop on multi-keyboard configurations.
        // Return every target to Auto before reporting failure so one successful
        // service is not left pinned after the retry budget is exhausted.
        guard successfulWrites == selection.targets.count else {
            let automaticValue = CapsLockLEDMode.automatic.eventSystemValue as NSString
            for service in selection.targets {
                _ = IOHIDServiceClientSetProperty(
                    service,
                    Self.capsLockLEDKey,
                    automaticValue
                )
            }
            throw CapsLockLEDControlError.writeRejected(
                targetCount: selection.targets.count,
                successfulWrites: successfulWrites
            )
        }

        return CapsLockLEDUpdateResult(
            matchedKeyboards: selection.all.count,
            targetedKeyboards: selection.targets.count,
            successfulWrites: successfulWrites
        )
    }

    func isModeApplied(_ mode: CapsLockLEDMode) throws -> Bool {
        let selection = try targetKeyboards()
        return selection.targets.allSatisfy { service in
            guard let property = IOHIDServiceClientCopyProperty(
                service,
                Self.capsLockLEDKey
            ) else {
                return false
            }
            return (property as? String) == mode.eventSystemValue
        }
    }

    private func targetKeyboards() throws -> (
        all: [IOHIDServiceClient],
        targets: [IOHIDServiceClient]
    ) {
        guard let serviceArray = IOHIDEventSystemClientCopyServices(client) else {
            throw CapsLockLEDControlError.servicesUnavailable
        }

        let keyboards = keyboardServices(in: serviceArray)
        guard !keyboards.isEmpty else {
            throw CapsLockLEDControlError.keyboardNotFound
        }

        // Prefer the built-in keyboard so an attached keyboard does not
        // unexpectedly become Capsomnia's status light. Drivers without the
        // Built-In property retain the previous all-keyboards fallback.
        let builtInKeyboards = keyboards.filter(isBuiltIn)
        return (
            all: keyboards,
            targets: builtInKeyboards.isEmpty ? keyboards : builtInKeyboards
        )
    }

    private func keyboardServices(in services: CFArray) -> [IOHIDServiceClient] {
        (0..<CFArrayGetCount(services)).compactMap { index in
            guard let rawService = CFArrayGetValueAtIndex(services, index) else {
                return nil
            }
            let service = unsafeBitCast(rawService, to: IOHIDServiceClient.self)
            let conforms = IOHIDServiceClientConformsTo(
                service,
                Self.genericDesktopUsagePage,
                Self.keyboardUsage
            )
            return conforms != 0 ? service : nil
        }
    }

    private func isBuiltIn(_ service: IOHIDServiceClient) -> Bool {
        guard let property = IOHIDServiceClientCopyProperty(service, Self.builtInKey) else {
            return false
        }
        return (property as? NSNumber)?.boolValue == true
    }
}

/// Retry state is separate from Dispatch so the three-equal-failures rule and
/// jitter range remain testable without HID hardware.
struct CapsLockLEDRetryPolicy {
    private(set) var consecutiveFailures = 0
    let baseDelay: TimeInterval

    init(baseDelay: TimeInterval = 0.025) {
        self.baseDelay = baseDelay
    }

    mutating func reset() {
        consecutiveFailures = 0
    }

    mutating func delayAfterFailure(randomUnit: Double) -> TimeInterval? {
        consecutiveFailures += 1
        guard consecutiveFailures < 3 else { return nil }

        let delay = baseDelay * pow(2, Double(consecutiveFailures - 1))
        let unit = min(max(randomUnit, 0), 1)
        return delay + ((delay / 2) * unit)
    }
}

/// Maintains the requested indicator state while a menu override is active.
///
/// macOS also writes `HIDCapsLockLED` while handling modifier transitions, even
/// when Caps Lock is remapped to Control. There is no public change callback for
/// this property, so the effective value is checked every 10 ms and rewritten
/// only after a mismatch is observed.
final class CapsLockLEDController {
    typealias Logger = (String) -> Void

    private let writer: CapsLockLEDWriting
    private let logger: Logger
    private let pollInterval: DispatchTimeInterval
    private let pollLeeway: DispatchTimeInterval
    private let queue = DispatchQueue(label: "com.github.fuji-mak.capsomnia.caps-lock-led")

    private var timer: DispatchSourceTimer?
    private var requestedState: Bool?
    private var requestReason = "unknown"
    private var nextAttemptNanoseconds: UInt64 = 0
    private var lastFailureSignature: String?
    private var haltedState: Bool?
    private var retryPolicy: CapsLockLEDRetryPolicy

    init(
        writer: CapsLockLEDWriting = EventSystemCapsLockLEDWriter(),
        retryPolicy: CapsLockLEDRetryPolicy = CapsLockLEDRetryPolicy(),
        pollInterval: DispatchTimeInterval = .milliseconds(10),
        pollLeeway: DispatchTimeInterval = .milliseconds(2),
        logger: @escaping Logger
    ) {
        self.writer = writer
        self.retryPolicy = retryPolicy
        self.pollInterval = pollInterval
        self.pollLeeway = pollLeeway
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
            let shouldRestart = stateChanged
                || environmentChanged
                || (self.timer == nil && self.haltedState != enabled)
            guard shouldRestart else { return }

            self.requestedState = enabled
            self.requestReason = reason
            self.nextAttemptNanoseconds = 0
            self.lastFailureSignature = nil
            self.haltedState = nil
            self.retryPolicy.reset()
            self.startTimerIfNeeded()
            self.pollAndRepairIfNeeded()
        }
    }

    /// Stops repairs before returning ownership to macOS. Queue serialization
    /// ensures an already-running repair cannot write after the final Auto.
    func restoreAutomatic(reason: String) {
        queue.async { [weak self] in
            self?.restoreAutomaticOnQueue(reason: reason)
        }
    }

    /// App termination must wait for an in-flight property write before exit.
    func restoreAutomaticImmediately(reason: String) {
        queue.sync {
            restoreAutomaticOnQueue(reason: reason)
        }
    }

    private func startTimerIfNeeded() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(
            deadline: .now() + pollInterval,
            repeating: pollInterval,
            leeway: pollLeeway
        )
        source.setEventHandler { [weak self] in
            self?.pollAndRepairIfNeeded()
        }
        timer = source
        source.resume()
    }

    private func stopTimer() {
        dispatchPrecondition(condition: .onQueue(queue))
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func pollAndRepairIfNeeded() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let requestedState, haltedState != requestedState else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        guard now >= nextAttemptNanoseconds else { return }

        let mode: CapsLockLEDMode = requestedState ? .on : .off
        do {
            if try !writer.isModeApplied(mode) {
                let result = try writer.setMode(mode)
                logger(
                    "\(requestReason) capslock_led=\(requestedState ? "on" : "off") "
                        + result.logDescription
                )
            }
            nextAttemptNanoseconds = 0
            lastFailureSignature = nil
            retryPolicy.reset()
        } catch {
            handleFailure(error, requestedState: requestedState, now: now)
        }
    }

    private func handleFailure(_ error: Error, requestedState: Bool, now: UInt64) {
        dispatchPrecondition(condition: .onQueue(queue))
        let signature = "\(String(reflecting: type(of: error))):\(error.localizedDescription)"
        if lastFailureSignature != signature {
            retryPolicy.reset()
            lastFailureSignature = signature
        }

        guard let delay = retryPolicy.delayAfterFailure(
            randomUnit: Double.random(in: 0...1)
        ) else {
            haltedState = requestedState
            stopTimer()
            let automaticRestore: String
            do {
                let result = try writer.setMode(.automatic)
                automaticRestore = "auto_restore=ok \(result.logDescription)"
            } catch {
                automaticRestore = "auto_restore=failed \(error.localizedDescription)"
            }
            logger(
                "\(requestReason) capslock_led_failed attempts=3 action=stopped "
                    + "\(error.localizedDescription) \(automaticRestore)"
            )
            return
        }

        nextAttemptNanoseconds = now + UInt64(delay * 1_000_000_000)
        logger(
            "\(requestReason) capslock_led_failed attempt=\(retryPolicy.consecutiveFailures) "
                + "retry_ms=\(Int(delay * 1_000)) \(error.localizedDescription)"
        )
    }

    private func restoreAutomaticOnQueue(reason: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        requestedState = nil
        haltedState = nil
        nextAttemptNanoseconds = 0
        lastFailureSignature = nil
        retryPolicy.reset()
        stopTimer()

        do {
            let result = try writer.setMode(.automatic)
            logger("\(reason) capslock_led_restore=auto \(result.logDescription)")
        } catch {
            logger("\(reason) capslock_led_restore_failed mode=auto \(error.localizedDescription)")
        }
    }
}
