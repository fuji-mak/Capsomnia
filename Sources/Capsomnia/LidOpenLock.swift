import Foundation

struct LidOpenLockRecord: Codable, Equatable {
    enum Outcome: String, Codable {
        case pending, locked, alreadyLocked, unconfirmed, unavailable, stateUnavailable
    }
    let id: UUID
    let openedAt: Date
    var closedAt: Date?
    var requestedAt: Date?
    var confirmedAt: Date?
    var outcome: Outcome
}

/// Main-thread state machine. Lock requests are injected so tests never lock the Mac.
final class LidOpenLockController {
    private(set) var record: LidOpenLockRecord?
    private var lastClosed: Bool?
    private var observedClosed: Bool?
    private var lastClosedAt: Date?
    private var pendingDeadline: Date?
    private let requestLock: () -> Bool
    private let save: (LidOpenLockRecord?) -> Void
    var onChange: ((LidOpenLockRecord) -> Void)?

    init(record: LidOpenLockRecord? = nil,
         requestLock: @escaping () -> Bool,
         save: @escaping (LidOpenLockRecord?) -> Void = { _ in }) {
        self.record = record
        self.requestLock = requestLock
        self.save = save
        // A restarted app cannot retrospectively prove when a pending request locked.
        if self.record?.outcome == .pending {
            self.record?.outcome = .unconfirmed
            save(self.record)
        }
    }

    func poll(closed: Bool?, eligible: Bool, locked: Bool?, now: Date) {
        // Observe closing even when automatic locking is disabled. Do not invent
        // a closing time when starting with a closed lid or after a read failure.
        if closed == nil {
            lastClosedAt = nil
        } else if closed == true && observedClosed == false {
            lastClosedAt = now
        }
        observedClosed = closed

        if let deadline = pendingDeadline, var event = record {
            if now >= deadline {
                event.outcome = .unconfirmed
                pendingDeadline = nil
                store(event)
            } else if locked == true {
                event.outcome = .locked
                event.confirmedAt = now
                pendingDeadline = nil
                store(event)
            }
        }

        if !eligible {
            lastClosed = nil
        } else if let closed {
            let opened = lastClosed == true && !closed
            lastClosed = closed
            if opened && pendingDeadline == nil {
                var event = LidOpenLockRecord(id: UUID(), openedAt: now, closedAt: lastClosedAt, outcome: .pending)
                if locked == true {
                    event.outcome = .alreadyLocked
                    store(event)
                } else if locked == nil {
                    event.outcome = .stateUnavailable
                    store(event)
                } else {
                    event.requestedAt = now
                    pendingDeadline = now.addingTimeInterval(5)
                    store(event)
                    if !requestLock() {
                        pendingDeadline = nil
                        event.outcome = .unavailable
                        store(event)
                    }
                }
            }
        } else {
            // Do not infer an edge across an unreadable lid-state interval.
            lastClosed = nil
        }

    }

    private func store(_ event: LidOpenLockRecord) {
        record = event
        save(event)
        onChange?(event)
    }
}
