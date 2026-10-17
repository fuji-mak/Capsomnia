import XCTest
@testable import Capsomnia

final class LidOpenLockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testClosingTimeTracksTransitionsEvenBeforeLockingIsEnabled() {
        let controller = LidOpenLockController(requestLock: { true })
        controller.poll(closed: false, eligible: false, locked: false, now: start)
        let closedAt = start.addingTimeInterval(1)
        controller.poll(closed: true, eligible: false, locked: false, now: closedAt)
        controller.poll(closed: true, eligible: true, locked: false, now: start.addingTimeInterval(10))
        controller.poll(closed: false, eligible: true, locked: false, now: start.addingTimeInterval(20))
        XCTAssertEqual(controller.record?.closedAt, closedAt)
        controller.poll(closed: false, eligible: true, locked: true, now: start.addingTimeInterval(21))
        let nextClose = start.addingTimeInterval(30)
        controller.poll(closed: true, eligible: true, locked: false, now: nextClose)
        controller.poll(closed: false, eligible: true, locked: false, now: start.addingTimeInterval(40))
        XCTAssertEqual(controller.record?.closedAt, nextClose)
    }

    func testUnknownClosingTimeIsNeverInvented() {
        let controller = LidOpenLockController(requestLock: { false })
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        controller.poll(closed: false, eligible: true, locked: false, now: start)
        XCTAssertNil(controller.record?.closedAt, "Startup while closed cannot determine closing time")
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        controller.poll(closed: nil, eligible: true, locked: false, now: start)
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        controller.poll(closed: false, eligible: true, locked: false, now: start)
        XCTAssertNil(controller.record?.closedAt, "An unreadable interval may contain another lid cycle")
    }

    func testLegacyRecordWithoutClosingTimeStillDecodes() throws {
        let original = LidOpenLockRecord(id: UUID(), openedAt: start, requestedAt: start,
                                        confirmedAt: start, outcome: .locked)
        let data = try JSONEncoder().encode(original)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("closedAt"))
        let restored = try JSONDecoder().decode(LidOpenLockRecord.self, from: data)
        XCTAssertEqual(restored, original)
    }

    func testOnlyAnEligibleClosedToOpenEdgeRequestsLockOnce() {
        var requests = 0
        let controller = LidOpenLockController(requestLock: { requests += 1; return true })
        controller.poll(closed: false, eligible: true, locked: false, now: start)
        XCTAssertEqual(requests, 0, "Starting with an open lid must not lock")
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        XCTAssertNil(controller.record, "Closing the lid must not lock")
        controller.poll(closed: false, eligible: true, locked: false, now: start.addingTimeInterval(10))
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(controller.record?.outcome, .pending)
        XCTAssertEqual(controller.record?.openedAt, start.addingTimeInterval(10))
        XCTAssertEqual(controller.record?.requestedAt, start.addingTimeInterval(10))
        XCTAssertNil(controller.record?.confirmedAt)
        for i in 1...4 {
            controller.poll(closed: false, eligible: true, locked: false, now: start.addingTimeInterval(10 + Double(i) / 4))
        }
        XCTAssertEqual(requests, 1)
    }

    func testConfirmedLockHasSeparateTimesAndPersistsWhileDisabled() {
        var saved: LidOpenLockRecord?
        let controller = LidOpenLockController(requestLock: { true }, save: { saved = $0 })
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        let opened = start.addingTimeInterval(2)
        controller.poll(closed: false, eligible: true, locked: false, now: opened)
        XCTAssertEqual(saved?.outcome, .pending)
        let locked = opened.addingTimeInterval(0.25)
        controller.poll(closed: false, eligible: true, locked: true, now: locked)
        XCTAssertEqual(saved?.confirmedAt, locked)
        XCTAssertEqual(saved?.outcome, .locked)
        controller.poll(closed: false, eligible: false, locked: nil, now: locked.addingTimeInterval(1))
        controller.poll(closed: false, eligible: false, locked: false, now: locked.addingTimeInterval(2))
        XCTAssertEqual(saved?.requestedAt, opened)
        XCTAssertEqual(saved?.confirmedAt, locked)
        XCTAssertEqual(saved?.outcome, .locked)
    }

    func testDisabledModeAndUnknownLidDoNotCreateSpuriousEdges() {
        let controller = LidOpenLockController(requestLock: { XCTFail("Unexpected lock"); return true })
        controller.poll(closed: true, eligible: false, locked: false, now: start)
        controller.poll(closed: false, eligible: true, locked: false, now: start)
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        controller.poll(closed: nil, eligible: true, locked: false, now: start)
        controller.poll(closed: false, eligible: true, locked: false, now: start)
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        controller.poll(closed: true, eligible: false, locked: false, now: start)
        controller.poll(closed: false, eligible: true, locked: false, now: start)
        XCTAssertNil(controller.record)
    }

    func testAlreadyLockedAndUnknownSessionDoNotClaimOwnLock() {
        for locked in [true, nil] as [Bool?] {
            let controller = LidOpenLockController(requestLock: { XCTFail("Unexpected lock"); return true })
            controller.poll(closed: true, eligible: true, locked: locked, now: start)
            controller.poll(closed: false, eligible: true, locked: locked, now: start)
            XCTAssertEqual(controller.record?.outcome, locked == true ? .alreadyLocked : .stateUnavailable)
            XCTAssertNil(controller.record?.requestedAt)
            XCTAssertNil(controller.record?.confirmedAt)
        }
    }

    func testUnavailableAPIAndConfirmationTimeoutAreNotSuccessAndDoNotRetry() {
        for available in [false, true] {
            var requests = 0
            let controller = LidOpenLockController(requestLock: { requests += 1; return available })
            controller.poll(closed: true, eligible: true, locked: false, now: start)
            controller.poll(closed: false, eligible: true, locked: false, now: start)
            controller.poll(closed: false, eligible: true, locked: false, now: start.addingTimeInterval(6))
            XCTAssertEqual(controller.record?.outcome, available ? .unconfirmed : .unavailable)
            XCTAssertNil(controller.record?.confirmedAt)
            XCTAssertEqual(requests, 1)
            controller.poll(closed: false, eligible: true, locked: true, now: start.addingTimeInterval(20))
            XCTAssertEqual(controller.record?.outcome, available ? .unconfirmed : .unavailable,
                           "A later unrelated lock must not be attributed to this request")
        }
    }

    func testRecordSurvivesRestartAndPendingRecordBecomesUnconfirmed() throws {
        for outcome in [LidOpenLockRecord.Outcome.locked, .pending] {
            let record = LidOpenLockRecord(id: UUID(), openedAt: start, requestedAt: start,
                                          confirmedAt: outcome == .locked ? start : nil, outcome: outcome)
            let restored = try JSONDecoder().decode(LidOpenLockRecord.self, from: JSONEncoder().encode(record))
            let controller = LidOpenLockController(record: restored, requestLock: { XCTFail("Unexpected lock"); return true })
            controller.poll(closed: false, eligible: false, locked: false, now: start)
            XCTAssertEqual(controller.record?.outcome, outcome == .locked ? .locked : .unconfirmed)
        }
    }

}
