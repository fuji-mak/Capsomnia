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

    /// Whether `minutes` maps to one of the fixed quick-pick chips.
    static func isQuickPick(_ minutes: Int) -> Bool {
        minuteOptions.contains(minutes)
    }
}

/// What the auto-off readout should show. Computed by the app delegate from the
/// live Caps Lock state and the pending timer state; rendered by the UI control.
enum AutoOffDisplayState: Equatable {
    /// Awake mode is off. Shows the remaining/armed duration (or infinity when `minutes == 0`).
    case idle(minutes: Int)
    /// Awake mode is on with no timer configured.
    case infinite
    /// Awake mode is on and a timer is running down.
    case counting(remaining: TimeInterval)
}

/// The timer bookkeeping the app delegate keeps between polls.
///
/// - `deadline` is set while awake mode is counting down.
/// - `pausedRemaining` holds the time left when awake mode is switched off, so
///   the countdown can resume where it left off (preserve mode).
struct AutoOffState: Equatable {
    var deadline: Date?
    var pausedRemaining: TimeInterval?

    init(deadline: Date? = nil, pausedRemaining: TimeInterval? = nil) {
        self.deadline = deadline
        self.pausedRemaining = pausedRemaining
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
    ///   - restartOnReenable: when `true`, re-enabling awake mode restarts the
    ///     full duration (old behavior). When `false`, the countdown pauses
    ///     while off and resumes where it left off.
    ///   - now: the current instant.
    ///   - state: the current timer state.
    /// - Returns: the next `state` to persist and `shouldFire`, which is `true`
    ///   exactly once when the countdown reaches zero.
    static func evaluate(
        capsLockOn: Bool,
        autoOffMinutes: Int,
        restartOnReenable: Bool,
        now: Date,
        state: AutoOffState
    ) -> (state: AutoOffState, shouldFire: Bool) {
        // Timer disabled: no deadline, no memory.
        guard autoOffMinutes > 0 else {
            return (AutoOffState(), false)
        }

        let fullDuration = TimeInterval(autoOffMinutes) * 60

        guard capsLockOn else {
            // Awake mode is off.
            if restartOnReenable {
                // Old behavior: keep no memory of elapsed time.
                return (AutoOffState(), false)
            }
            if let deadline = state.deadline {
                // Was counting: pause and remember the time remaining.
                let remaining = max(0, deadline.timeIntervalSince(now))
                return (AutoOffState(deadline: nil, pausedRemaining: remaining), false)
            }
            // Already paused, or never started: keep whatever was remembered.
            return (AutoOffState(deadline: nil, pausedRemaining: state.pausedRemaining), false)
        }

        // Awake mode is on.
        if let deadline = state.deadline {
            if now >= deadline {
                return (AutoOffState(), true)
            }
            return (AutoOffState(deadline: deadline, pausedRemaining: nil), false)
        }

        // Just turned on (or the timer was just (re)armed): begin counting.
        let remaining = restartOnReenable
            ? fullDuration
            : (state.pausedRemaining ?? fullDuration)
        if remaining <= 0 {
            return (AutoOffState(), true)
        }
        return (AutoOffState(deadline: now.addingTimeInterval(remaining), pausedRemaining: nil), false)
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
            return AutoOffState(deadline: now.addingTimeInterval(fullDuration), pausedRemaining: nil)
        }
        // Awake mode is off: arm the full duration to resume when re-enabled.
        return AutoOffState(deadline: nil, pausedRemaining: fullDuration)
    }
}

/// Formatting helpers for the auto-off readout and chips.
enum AutoOffFormatter {
    /// `HH:MM:SS` countdown, clamped at zero and never negative.
    static func countdown(_ remaining: TimeInterval) -> String {
        let (hours, minutes, seconds) = components(remaining)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Compact menu-bar countdown: "M:SS" under an hour, "H:MM:SS" otherwise.
    static func menuBar(_ remaining: TimeInterval) -> String {
        let (hours, minutes, seconds) = components(remaining)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
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
