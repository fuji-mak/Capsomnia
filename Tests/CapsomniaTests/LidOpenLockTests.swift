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
        let text = LidOpenLockText.localized(.simplifiedChinese)
        let lines = text.details(restored).components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "最近一次合盖：未记录")
        XCTAssertTrue(lines[1].hasPrefix("检测到开盖："))
        XCTAssertTrue(lines[2].hasPrefix("确认已锁定："))
        XCTAssertFalse(lines.contains { $0.hasPrefix("请求锁定：") })
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

    func testConfirmationAndUnlockNoticeHaveSeparateTimesAndPersist() {
        var saved: LidOpenLockRecord?
        var notices: [LidOpenLockRecord] = []
        var notifications = 0
        let controller = LidOpenLockController(requestLock: { true }, save: { saved = $0 })
        controller.onNotice = { notices.append($0) }
        controller.onConfirmed = { _ in notifications += 1 }
        controller.poll(closed: true, eligible: true, locked: false, now: start)
        let opened = start.addingTimeInterval(2)
        controller.poll(closed: false, eligible: true, locked: false, now: opened)
        XCTAssertTrue(notices.isEmpty)
        let locked = opened.addingTimeInterval(0.25)
        controller.poll(closed: false, eligible: true, locked: true, now: locked)
        XCTAssertEqual(saved?.confirmedAt, locked)
        XCTAssertEqual(saved?.outcome, .locked)
        XCTAssertEqual(notifications, 1)
        XCTAssertTrue(notices.isEmpty, "Never display application UI over the lock screen")
        controller.poll(closed: false, eligible: false, locked: nil, now: locked.addingTimeInterval(1))
        XCTAssertTrue(notices.isEmpty, "Unknown/background session is not an unlock")
        controller.poll(closed: false, eligible: false, locked: false, now: locked.addingTimeInterval(2))
        controller.poll(closed: false, eligible: false, locked: false, now: locked.addingTimeInterval(3))
        XCTAssertEqual(notices.count, 1)
        XCTAssertEqual(notices[0].requestedAt, opened)
        controller.acknowledge(notices[0].id)
        XCTAssertEqual(saved?.acknowledged, true)
        XCTAssertEqual(saved?.confirmedAt, locked, "Acknowledgement retains the record")
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
            var notices = 0
            let controller = LidOpenLockController(record: restored, requestLock: { XCTFail("Unexpected lock"); return true })
            controller.onNotice = { _ in notices += 1 }
            controller.poll(closed: false, eligible: false, locked: false, now: start)
            XCTAssertEqual(notices, 1)
            XCTAssertEqual(controller.record?.outcome, outcome == .locked ? .locked : .unconfirmed)
        }
    }

    func testAcknowledgedRecordIsNotShownAgainAfterRestart() {
        let record = LidOpenLockRecord(id: UUID(), openedAt: start, outcome: .locked, acknowledged: true)
        let controller = LidOpenLockController(record: record, requestLock: { true })
        controller.onNotice = { _ in XCTFail("Already acknowledged") }
        controller.poll(closed: false, eligible: true, locked: false, now: start)
    }
}
