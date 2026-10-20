import Foundation
import IOKit
import IOKit.hidsystem

enum CapsLockToggleResult: Equatable {
    case changed(to: Bool)
    case unavailable
    case writeFailed(target: Bool)
    case verificationFailed(target: Bool, actual: Bool?)
}

struct CapsLockStateConfirmationResult: Equatable {
    let confirmed: Bool
    let actual: Bool?
}

struct CapsLockStateConfirmation {
    let readState: () -> Bool?
    let wait: () -> Void
    let maximumAttempts: Int
    let requiredConsecutiveMatches: Int

    func confirm(target: Bool) -> CapsLockStateConfirmationResult {
        precondition(maximumAttempts > 0)
        precondition(requiredConsecutiveMatches > 0)

        var consecutiveMatches = 0
        var actual: Bool?

        for attempt in 0..<maximumAttempts {
            actual = readState()
            if actual == target {
                consecutiveMatches += 1
                if consecutiveMatches >= requiredConsecutiveMatches {
                    return CapsLockStateConfirmationResult(
                        confirmed: true,
                        actual: actual
                    )
                }
            } else {
                consecutiveMatches = 0
            }

            if attempt + 1 < maximumAttempts {
                wait()
            }
        }

        return CapsLockStateConfirmationResult(
            confirmed: false,
            actual: actual
        )
    }
}

/// Reconcile the per-keyboard state used by IOHIDSetModifierLockState with the
/// global flags read by IOHIDGetModifierLockState. Apple's keyboard filter skips
/// writes equal to its cached state, even if the global flags disagree.
struct CapsLockStateWriter {
    let writeState: (Bool) -> Bool
    let confirmation: CapsLockStateConfirmation
    var onReconcile: (Bool, Bool) -> Void = { _, _ in }

    func set(_ target: Bool) -> CapsLockToggleResult {
        guard writeState(target) else { return .writeFailed(target: target) }
        let first = confirmation.confirm(target: target)
        if first.confirmed { return .changed(to: target) }

        // Only recover a known mismatch. Never pulse to an invented opposite
        // state when reads are unavailable or merely not yet stable.
        guard let actual = first.actual, actual != target else {
            return .verificationFailed(target: target, actual: first.actual)
        }
        // Read again before resetting caches: a delayed successful transition
        // must not be undone by recovery based on a stale observation.
        let current = confirmation.confirm(target: target)
        if current.confirmed { return .changed(to: target) }
        guard current.actual == actual else {
            return .verificationFailed(target: target, actual: current.actual)
        }

        onReconcile(target, actual)
        // Set the state the system already reports, not an arbitrary toggle.
        // Then generate a real transition to the user's target. Exactly one
        // reconciliation is allowed; persistent interference remains a failure.
        guard writeState(actual) else { return .writeFailed(target: target) }
        let baseline = confirmation.confirm(target: actual)
        guard baseline.confirmed else {
            return .verificationFailed(target: target, actual: baseline.actual)
        }
        guard writeState(target) else { return .writeFailed(target: target) }
        let final = confirmation.confirm(target: target)
        return final.confirmed ? .changed(to: target)
            : .verificationFailed(target: target, actual: final.actual)
    }
}

enum CapsLockHIDSystem {
    static func openConnection() -> io_connect_t? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDSystemClass)
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(
            service,
            mach_task_self_,
            UInt32(kIOHIDParamConnectType),
            &connection
        ) == KERN_SUCCESS else {
            return nil
        }

        return connection
    }

    static func readState(connection: io_connect_t) -> Bool? {
        var state = false
        guard IOHIDGetModifierLockState(
            connection,
            Int32(kIOHIDCapsLockState),
            &state
        ) == KERN_SUCCESS else {
            return nil
        }
        return state
    }

    static func setState(
        _ state: Bool,
        connection: io_connect_t
    ) -> Bool {
        IOHIDSetModifierLockState(
            connection,
            Int32(kIOHIDCapsLockState),
            state
        ) == KERN_SUCCESS
    }
}

final class SystemCapsLockStateReader {
    private let lock = NSLock()
    private var connection: io_connect_t = 0

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func currentState() -> Bool? {
        lock.lock()
        defer { lock.unlock() }

        if connection == 0 {
            connection = CapsLockHIDSystem.openConnection() ?? 0
        }
        guard connection != 0 else { return nil }

        if let state = CapsLockHIDSystem.readState(connection: connection) {
            return state
        }

        IOServiceClose(connection)
        connection = CapsLockHIDSystem.openConnection() ?? 0
        guard connection != 0 else { return nil }
        return CapsLockHIDSystem.readState(connection: connection)
    }
}

enum SystemCapsLockController {
    private static let eventLock = NSLock()
    private static var internalEventsUntil: TimeInterval = 0
    private static var writing = false

    static func isInternalKeyEvent(timestamp: TimeInterval) -> Bool {
        eventLock.lock()
        defer { eventLock.unlock() }
        return writing || timestamp <= internalEventsUntil
    }

    private static func markWrite(_ active: Bool) {
        eventLock.lock()
        writing = active
        internalEventsUntil = ProcessInfo.processInfo.systemUptime + 0.5
        eventLock.unlock()
    }

    static func set(_ target: Bool) -> CapsLockToggleResult {
        markWrite(true)
        defer { markWrite(false) }
        guard let connection = CapsLockHIDSystem.openConnection() else {
            return .unavailable
        }
        defer { IOServiceClose(connection) }

        return set(target, connection: connection)
    }

    private static func set(
        _ target: Bool,
        connection: io_connect_t
    ) -> CapsLockToggleResult {
        let confirmation = CapsLockStateConfirmation(
            readState: {
                CapsLockHIDSystem.readState(connection: connection)
            },
            wait: {
                Thread.sleep(forTimeInterval: 0.02)
            },
            maximumAttempts: 25,
            requiredConsecutiveMatches: 3
        )
        return CapsLockStateWriter(
            writeState: { CapsLockHIDSystem.setState($0, connection: connection) },
            confirmation: confirmation,
            onReconcile: { target, actual in
                NSLog("capslock_reconcile target=%@ observed=%@", target ? "on" : "off", actual ? "on" : "off")
            }
        ).set(target)
    }
}

final class CapsLockToggleCoordinator {
    private let queue: OperationQueue
    private let setState: (Bool) -> CapsLockToggleResult

    init(
        setState: @escaping (Bool) -> CapsLockToggleResult = SystemCapsLockController.set
    ) {
        let queue = OperationQueue()
        queue.name = "\(appLabel).caps-lock-toggle"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        self.queue = queue
        self.setState = setState
    }

    /// Serialize explicit state changes so an auto-off never races a manual toggle.
    func requestSet(_ target: Bool, completion: @escaping (CapsLockToggleResult) -> Void) {
        let setState = self.setState
        queue.addOperation {
            let result = setState(target)
            OperationQueue.main.addOperation {
                completion(result)
            }
        }
    }
}
