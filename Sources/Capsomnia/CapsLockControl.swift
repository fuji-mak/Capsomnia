import Foundation
import IOKit
import IOKit.hidsystem

enum CapsLockToggleResult: Equatable {
    case changed(to: Bool)
    case unavailable
    case readFailed
    case writeFailed(target: Bool)
    case verificationFailed(target: Bool, actual: Bool?)
}

struct CapsLockToggleTransaction {
    let readState: () -> Bool?
    let setState: (Bool) -> Bool

    func run() -> CapsLockToggleResult {
        guard let current = readState() else {
            return .readFailed
        }

        let target = !current
        guard setState(target) else {
            return .writeFailed(target: target)
        }

        let actual = readState()
        guard actual == target else {
            return .verificationFailed(target: target, actual: actual)
        }

        return .changed(to: target)
    }
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
    static func toggle() -> CapsLockToggleResult {
        guard let connection = CapsLockHIDSystem.openConnection() else {
            return .unavailable
        }
        defer { IOServiceClose(connection) }

        guard let current = CapsLockHIDSystem.readState(connection: connection) else {
            return .readFailed
        }

        return set(!current, connection: connection)
    }

    static func set(_ target: Bool) -> CapsLockToggleResult {
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
        guard CapsLockHIDSystem.setState(
            target,
            connection: connection
        ) else {
            return .writeFailed(target: target)
        }

        let immediateState = CapsLockHIDSystem.readState(connection: connection)
        guard immediateState == target else {
            return .verificationFailed(
                target: target,
                actual: immediateState
            )
        }

        let confirmation = CapsLockStateConfirmation(
            readState: {
                CapsLockHIDSystem.readState(connection: connection)
            },
            wait: {
                Thread.sleep(forTimeInterval: 0.02)
            },
            maximumAttempts: 25,
            requiredConsecutiveMatches: 3
        ).confirm(target: target)

        guard confirmation.confirmed else {
            return .verificationFailed(
                target: target,
                actual: confirmation.actual
            )
        }

        return .changed(to: target)
    }
}

final class CapsLockToggleCoordinator {
    private let queue: OperationQueue
    private let toggle: () -> CapsLockToggleResult

    init(toggle: @escaping () -> CapsLockToggleResult = SystemCapsLockController.toggle) {
        let queue = OperationQueue()
        queue.name = "\(appLabel).caps-lock-toggle"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        self.queue = queue
        self.toggle = toggle
    }

    func requestToggle(completion: @escaping (CapsLockToggleResult) -> Void) {
        let toggle = self.toggle
        queue.addOperation {
            let result = toggle()
            OperationQueue.main.addOperation {
                completion(result)
            }
        }
    }
}
