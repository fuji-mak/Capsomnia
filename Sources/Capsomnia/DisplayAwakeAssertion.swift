import Foundation
import IOKit.pwr_mgt

/// Holds a `PreventUserIdleDisplaySleep` power assertion so the display stays
/// on while Capsomnia keeps the system awake. The assertion only blocks
/// idle-timeout display sleep; a forced `pmset displaysleepnow` (used by
/// "Turn display off when lid closes") still turns the display off. Runs as
/// the current user — no privileged helper is involved — and macOS releases
/// the assertion automatically if the process exits.
///
/// Uses IOKit directly instead of `ProcessInfo.beginActivity(options:reason:)`
/// because the IOKit calls return per-call status codes, which the caller
/// needs for the app's verify-log-retry pattern; the Foundation API has no
/// failure signal.
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
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "\(appName) keeps the display awake" as CFString,
                &id
            )
            guard status == kIOReturnSuccess else { return false }
            assertionID = id
            return true
        }

        guard let id = assertionID else { return true }
        // A failed release can leave the assertion alive in powerd (for
        // example when the power-management connection fails), so keep the ID
        // for the caller's retry instead of clearing it.
        guard IOPMAssertionRelease(id) == kIOReturnSuccess else { return false }
        assertionID = nil
        return true
    }
}
