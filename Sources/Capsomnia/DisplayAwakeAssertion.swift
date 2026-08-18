import Foundation
import IOKit.pwr_mgt

/// Holds a `PreventUserIdleDisplaySleep` power assertion so the display stays
/// on while Capsomnia keeps the system awake. The assertion only blocks
/// idle-timeout display sleep; a forced `pmset displaysleepnow` (used by
/// "Turn display off when lid closes") still turns the display off. Runs as
/// the current user — no privileged helper is involved — and macOS releases
/// the assertion automatically if the process exits.
final class DisplayAwakeAssertion {
    private var assertionID: IOPMAssertionID?

    var isActive: Bool {
        assertionID != nil
    }

    /// Idempotently creates or releases the assertion.
    /// Returns `true` when the requested state is in effect.
    @discardableResult
    func setActive(_ active: Bool) -> Bool {
        if active {
            guard assertionID == nil else { return true }
            var id = IOPMAssertionID(0)
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "\(appName) keeps the display awake" as CFString,
                &id
            )
            guard status == kIOReturnSuccess else { return false }
            assertionID = id
            return true
        }

        guard let id = assertionID else { return true }
        assertionID = nil
        IOPMAssertionRelease(id)
        return true
    }
}
