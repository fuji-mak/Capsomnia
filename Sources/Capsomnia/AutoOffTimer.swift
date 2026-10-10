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

/// Carries an elapsed auto-off through the existing Caps Lock and helper
/// synchronization path, then requests immediate system sleep exactly once,
/// only if the lid is still closed. Open or unknown lid state never sleeps.
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
    func requestSleepIfReady(capsLockOn: Bool, clamshellClosed: Bool?) -> CommandResult? {
        guard isPending else { return nil }
        isPending = false
        guard !capsLockOn, clamshellClosed == true else { return nil }
        return requestSleep()
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

/// Compact labels used by the menu-bar timer item.
enum AutoOffMenuFormatter {
    static func title(
        base: String,
        turnsOffIn: String,
        state: AutoOffDisplayState
    ) -> String {
        guard case let .counting(remaining) = state else { return base }
        return "\(base) (\(turnsOffIn) \(AutoOffFormatter.countdown(remaining)))"
    }

    static func customTitle(base: String, selectedMinutes: Int) -> String {
        guard selectedMinutes > 0,
              !AutoOffPreset.isQuickPick(selectedMinutes) else { return base }
        return "\(base) (\(AutoOffFormatter.durationLabel(minutes: selectedMinutes)))"
    }
}

enum AutoOffMenuSelectionPolicy {
    /// Reselecting the active duration must not restart a running countdown.
    static func shouldApply(currentMinutes: Int, selectedMinutes: Int) -> Bool {
        currentMinutes != selectedMinutes
    }
}
