/// Transient command state shared by menu/shortcut, CLI and auto-off paths.
/// Hardware state and timer/sleep policies remain with their existing owners.
struct AwakeControlState {
    enum Operation: Hashable {
        case manual, cli, autoOff
    }

    private var operations: Set<Operation> = []
    private(set) var failedTogglePhysicalState: Bool?
    private(set) var secureInputCapsLockOverrideActive = false
    private(set) var secureInputOverrideSuppressedForExplicitOff = false

    var isChanging: Bool { !operations.isEmpty }

    func isInFlight(_ operation: Operation) -> Bool {
        operations.contains(operation)
    }

    /// Preserve the existing per-path admission rules: distinct operations
    /// may overlap, and finishing one must not clear another's in-flight state.
    mutating func begin(_ operation: Operation, target: Bool) -> Bool {
        guard operations.insert(operation).inserted else { return false }
        // Timer expiry retains the previous failure until its hardware result;
        // manual and CLI requests clear it immediately, as before.
        if operation != .autoOff { failedTogglePhysicalState = nil }
        secureInputOverrideSuppressedForExplicitOff = !target
        if !target { secureInputCapsLockOverrideActive = false }
        return true
    }

    mutating func finish(_ operation: Operation, failureState: Bool?) {
        operations.remove(operation)
        if let failureState {
            failedTogglePhysicalState = failureState
        } else if operation != .cli {
            // CLI completion also includes helper/sleep confirmation. Its
            // success must not erase a failure recorded by an overlapping path.
            failedTogglePhysicalState = nil
        }
    }

    mutating func observePhysicalCapsLock(_ on: Bool) {
        if on { secureInputOverrideSuppressedForExplicitOff = false }
    }

    mutating func setSecureInputOverrideActive(_ active: Bool) {
        secureInputCapsLockOverrideActive = active
    }

    mutating func reconcileToggleFailure(physicalCapsLock: Bool?) {
        if let failed = failedTogglePhysicalState,
           let physicalCapsLock, physicalCapsLock != failed {
            failedTogglePhysicalState = nil
        }
    }
}
