/// Chooses between the physical Caps Lock state and the menu bar override.
///
/// Polling must not immediately erase a manual choice. A real Caps Lock
/// transition still takes control back, so existing users do not need a second
/// menu action to return to the app's original hardware-driven behavior. When
/// Caps Lock is remapped to Control, alphaShift never changes and the manual
/// choice therefore remains active.
struct SleepStateSelection {
    struct Resolution: Equatable {
        let sleepPreventionOn: Bool
        let clearedManualOverride: Bool
    }

    private var lastObservedHardwareState: Bool?
    private(set) var manualOverride: Bool?

    var desiredState: Bool? {
        manualOverride ?? lastObservedHardwareState
    }

    mutating func observeHardwareState(_ hardwareState: Bool) -> Resolution {
        let hardwareChanged = lastObservedHardwareState.map { $0 != hardwareState } ?? false
        let clearedManualOverride = hardwareChanged && manualOverride != nil

        if hardwareChanged {
            manualOverride = nil
        }

        lastObservedHardwareState = hardwareState
        return Resolution(
            sleepPreventionOn: manualOverride ?? hardwareState,
            clearedManualOverride: clearedManualOverride
        )
    }

    mutating func setManualOverride(_ enabled: Bool) {
        manualOverride = enabled
    }
}
