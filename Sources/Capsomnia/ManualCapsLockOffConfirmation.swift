import Foundation

/// A recent HID press may explain the next physical OFF. This is only a
/// one-use confirmation for skipping debounce, never a requested awake state.
struct ManualCapsLockOffConfirmation {
    private var deadline: Date?

    mutating func begin(now: Date, validFor interval: TimeInterval) {
        deadline = now.addingTimeInterval(interval)
    }

    mutating func cancel() {
        deadline = nil
    }

    mutating func consume(physicalCapsLockOn: Bool, now: Date) -> Bool {
        guard let deadline else { return false }
        guard now < deadline else {
            cancel()
            return false
        }
        // HID input can arrive before the OS updates the modifier state.
        guard !physicalCapsLockOn else { return false }
        cancel()
        return true
    }
}
