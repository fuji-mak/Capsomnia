import Foundation

/// A CLI override belongs to the current awake session, never to UserDefaults.
struct SessionAutoOffTimer {
    private(set) var overrideSeconds: TimeInterval?
    private(set) var deadline: Date?

    var source: String {
        guard let overrideSeconds else { return "settings" }
        return overrideSeconds == 0 ? "cancelled" : "one-shot"
    }

    func duration(defaultMinutes: Int) -> TimeInterval {
        overrideSeconds ?? TimeInterval(defaultMinutes * 60)
    }

    mutating func set(seconds: TimeInterval, now: Date) {
        overrideSeconds = seconds
        deadline = now.addingTimeInterval(seconds)
    }

    mutating func cancel() {
        overrideSeconds = 0
        deadline = nil
    }

    mutating func reset() {
        self = SessionAutoOffTimer()
    }

    mutating func restart(capsLockOn: Bool, defaultMinutes: Int, now: Date) {
        let seconds = duration(defaultMinutes: defaultMinutes)
        deadline = capsLockOn && seconds > 0 ? now.addingTimeInterval(seconds) : nil
    }

    mutating func evaluate(capsLockOn: Bool, defaultMinutes: Int, now: Date) -> Bool {
        guard capsLockOn else {
            reset()
            return false
        }
        let seconds = duration(defaultMinutes: defaultMinutes)
        guard seconds > 0 else {
            deadline = nil
            return false
        }
        if let deadline {
            if now >= deadline {
                // Keep the elapsed timer cancelled until OFF is observed,
                // including when the hardware OFF fails.
                cancel()
                return true
            }
        } else {
            deadline = now.addingTimeInterval(seconds)
        }
        return false
    }
}
