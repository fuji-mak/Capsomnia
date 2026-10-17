import Foundation

/// Keyboard state is an input, not the lifetime of an awake session. Adopt it
/// once at startup; only confirmed commands and observed Caps Lock key events
/// may subsequently change the requested mode. Focus/input-source polling is
/// deliberately observational, including when the hardware read is unavailable.
struct AwakeSessionState {
    private(set) var requested: Bool?

    mutating func observe(physical: Bool?) {
        if requested == nil { requested = physical }
    }

    mutating func recordCommand(_ result: CapsLockToggleResult) {
        if case let .changed(target) = result { requested = target }
    }

    mutating func recordKey(target: Bool) {
        requested = target
    }
}
