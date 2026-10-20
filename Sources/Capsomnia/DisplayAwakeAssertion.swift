import Foundation
import IOKit.pwr_mgt

/// Holds a `PreventUserIdleDisplaySleep` power assertion so the display stays
/// on while Capsomnia keeps the system awake. Lid-close handling skips its
/// forced `pmset displaysleepnow` request while this preference is enabled.
/// Runs as the current user — no privileged helper is involved — and macOS
/// releases the assertion automatically if the process exits.
///
/// Uses IOKit directly instead of `ProcessInfo.beginActivity(options:reason:)`
/// because the IOKit calls return per-call status codes, which the caller
/// needs for the app's verify-log-retry pattern; the Foundation API has no
/// failure signal.
final class DisplayAwakeAssertion {
    private let create: (UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn
    private let release: (IOPMAssertionID) -> IOReturn
    private var assertionID: IOPMAssertionID?
    private var activityID: IOPMAssertionID?
    private let declareActivity: (UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn
    private let scheduleHeartbeat: (@escaping () -> Void) -> (() -> Void)
    private var cancelHeartbeat: (() -> Void)?
    private(set) var isHealthy = true

    init(
        create: @escaping (UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn = { id in
            IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "\(appName) keeps the display awake" as CFString,
                id
            )
        },
        release: @escaping (IOPMAssertionID) -> IOReturn = IOPMAssertionRelease,
        declareActivity: @escaping (UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn = { id in
            IOPMAssertionDeclareUserActivity("Capsomnia display session" as CFString, kIOPMUserActiveLocal, id)
        },
        scheduleHeartbeat: @escaping (@escaping () -> Void) -> (() -> Void) = { action in
            let timer = Timer(timeInterval: 30, repeats: true) { _ in action() }
            RunLoop.main.add(timer, forMode: .common)
            return { timer.invalidate() }
        }
    ) {
        self.create = create
        self.release = release
        self.declareActivity = declareActivity
        self.scheduleHeartbeat = scheduleHeartbeat
    }

    var isActive: Bool {
        assertionID != nil || activityID != nil
    }

    /// Idempotently creates or releases the assertion.
    /// Returns `true` when the requested state is in effect.
    @discardableResult
    func setActive(_ active: Bool) -> Bool {
        if active {
            if assertionID == nil {
                var id = IOPMAssertionID(0)
                guard create(&id) == kIOReturnSuccess else { isHealthy = false; return false }
                assertionID = id
            }
            if cancelHeartbeat == nil {
                heartbeat()
                cancelHeartbeat = scheduleHeartbeat { [weak self] in self?.heartbeat() }
            } else if !isHealthy {
                heartbeat()
            }
            return isHealthy
        }

        cancelHeartbeat?()
        cancelHeartbeat = nil
        let displayReleased = releaseHeld(&assertionID)
        let activityReleased = releaseHeld(&activityID)
        isHealthy = displayReleased && activityReleased
        return isHealthy
    }

    private func heartbeat() {
        var id = activityID ?? IOPMAssertionID(0)
        let status = declareActivity(&id)
        isHealthy = status == kIOReturnSuccess
        if isHealthy { activityID = id }
        else if status == kIOReturnBadArgument || status == kIOReturnNotPermitted { activityID = nil }
    }

    private func releaseHeld(_ held: inout IOPMAssertionID?) -> Bool {
        guard let id = held else { return true }
        switch release(id) {
        case kIOReturnSuccess, kIOReturnBadArgument, kIOReturnNotPermitted:
            held = nil
            return true
        default:
            return false
        }
    }
}
