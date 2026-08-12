import Foundation

/// Preset auto-off durations offered in the UI, in minutes.
///
/// `0` is a distinct "no timer" state (awake mode stays on until Caps Lock is
/// turned off manually). It is offered separately as the "Off" chip rather than
/// living in `minuteOptions`.
enum AutoOffPreset {
    /// Finite quick-pick durations, in minutes.
    static let minuteOptions: [Int] = [15, 30, 60, 120, 240, 480]

    /// Lower/upper bounds for the custom picker.
    static let minCustomMinutes = 1
    static let maxCustomMinutes = 24 * 60
    static let customHourStep = 60
    static let customMinuteStep = 1

    /// Whether `minutes` maps to one of the fixed quick-pick chips.
    static func isQuickPick(_ minutes: Int) -> Bool {
        minuteOptions.contains(minutes)
    }

    /// Apply a custom-picker step while keeping the result within its bounds.
    static func adjustedCustomMinutes(_ minutes: Int, by delta: Int) -> Int {
        min(max(minutes + delta, minCustomMinutes), maxCustomMinutes)
    }
}

/// What the auto-off readout should show. Computed by the app delegate from the
/// live Caps Lock state and the pending timer state; rendered by the UI control.
enum AutoOffDisplayState: Equatable {
    /// Awake mode is off. Shows the configured duration (or infinity when `minutes == 0`).
    case idle(minutes: Int)
    /// Awake mode is on with no timer configured.
    case infinite
    /// Awake mode is on and a timer is running down.
    case counting(remaining: TimeInterval)
}

/// The timer bookkeeping the app delegate keeps between polls.
///
/// - `deadline` is set while awake mode is counting down.
struct AutoOffState: Equatable {
    var deadline: Date?

    init(deadline: Date? = nil) {
        self.deadline = deadline
    }
}

/// Carries an elapsed auto-off through the existing Caps Lock and helper
/// synchronization path, then requests immediate system sleep exactly once.
///
/// The app only calls `requestSleepIfReady` after `SleepDisabled` has been
/// confirmed to match the current Caps Lock state. Keeping the pending bit here
/// makes that ordering explicit and testable without sleeping the test Mac.
final class AutoOffSleepCoordinator {
    private(set) var isPending = false
    private let requestSleep: () -> CommandResult

    init(
        requestSleep: @escaping () -> CommandResult = {
            SystemSleepRequester.request()
        }
    ) {
        self.requestSleep = requestSleep
    }

    func recordCapsLockResult(_ result: CapsLockToggleResult) {
        isPending = result == .changed(to: false)
    }

    /// Requests sleep once the confirmed state is OFF. A confirmed ON state
    /// means the user re-enabled awake mode before completion, so the pending
    /// sleep is cancelled rather than firing later against their intent.
    func requestSleepIfReady(capsLockOn: Bool) -> CommandResult? {
        guard isPending else { return nil }

        if capsLockOn {
            isPending = false
            return nil
        }

        isPending = false
        return requestSleep()
    }
}

/// Pure scheduling policy for the auto-off timer. No side effects, so the whole
/// behavior can be unit-tested without hardware, timers, or a run loop.
enum AutoOffPolicy {
    /// Advance the timer state and decide whether awake mode should turn off now.
    ///
    /// - Parameters:
    ///   - capsLockOn: whether awake mode (Caps Lock) is currently on.
    ///   - autoOffMinutes: the configured duration; `0` disables the timer.
    ///   - now: the current instant.
    ///   - state: the current timer state.
    /// - Returns: the next `state` to persist and `shouldFire`, which is `true`
    ///   exactly once when the countdown reaches zero.
    static func evaluate(
        capsLockOn: Bool,
        autoOffMinutes: Int,
        now: Date,
        state: AutoOffState
    ) -> (state: AutoOffState, shouldFire: Bool) {
        // Timer disabled: no deadline, no memory.
        guard autoOffMinutes > 0 else {
            return (AutoOffState(), false)
        }

        let fullDuration = TimeInterval(autoOffMinutes) * 60

        guard capsLockOn else {
            // Turning awake mode off ends the current timer session. The next
            // re-enable always starts a fresh full-duration countdown.
            return (AutoOffState(), false)
        }

        // Awake mode is on.
        if let deadline = state.deadline {
            if now >= deadline {
                return (AutoOffState(), true)
            }
            return (AutoOffState(deadline: deadline), false)
        }

        // Just turned on (or the timer was just re-armed): begin a fresh countdown.
        return (AutoOffState(deadline: now.addingTimeInterval(fullDuration)), false)
    }

    /// A fresh full-duration state for the explicit Restart action.
    static func restarted(
        capsLockOn: Bool,
        autoOffMinutes: Int,
        now: Date
    ) -> AutoOffState {
        guard autoOffMinutes > 0 else { return AutoOffState() }
        let fullDuration = TimeInterval(autoOffMinutes) * 60
        if capsLockOn {
            return AutoOffState(deadline: now.addingTimeInterval(fullDuration))
        }
        // Awake mode is off: the next re-enable starts the full duration anyway.
        return AutoOffState()
    }
}

/// Formatting helpers for the auto-off readout and chips.
enum AutoOffFormatter {
    /// `HH:MM:SS` countdown, clamped at zero and never negative.
    static func countdown(_ remaining: TimeInterval) -> String {
        let (hours, minutes, seconds) = components(remaining)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Compact, language-neutral duration label: "∞", "15m", "1h", "1h 30m".
    static func durationLabel(minutes: Int) -> String {
        guard minutes > 0 else { return "∞" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    private static func components(_ remaining: TimeInterval) -> (Int, Int, Int) {
        let total = max(0, Int(remaining.rounded(.down)))
        return (total / 3600, (total % 3600) / 60, total % 60)
    }
}
