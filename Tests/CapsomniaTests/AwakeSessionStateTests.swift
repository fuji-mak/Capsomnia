import XCTest
import CoreGraphics
@testable import Capsomnia

final class AwakeSessionStateTests: XCTestCase {
    func testStartupAdoptsFirstAvailableStateOnly() {
        var state = AwakeSessionState()
        state.observe(physical: nil)
        XCTAssertNil(state.requested)
        state.observe(physical: false)
        state.observe(physical: true)
        XCTAssertEqual(state.requested, false)
    }

    func testAmbientOffAfterTwoHoursDoesNotEndSessionOrResetTimer() {
        var state = AwakeSessionState()
        state.recordCommand(.changed(to: true))
        var timer = SessionAutoOffTimer()
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(timer.evaluate(capsLockOn: state.requested!, defaultMinutes: 180, now: start))
        let deadline = timer.deadline
        // Replay the observed ON -> ambient OFF -> focus/poll path. No key or
        // explicit OFF command occurred. Repeated polls must retain the session.
        for second in stride(from: 7200, through: 9000, by: 1) {
            state.observe(physical: second % 2 == 0 ? false : nil)
            XCTAssertEqual(state.requested, true)
            XCTAssertFalse(timer.evaluate(capsLockOn: state.requested!, defaultMinutes: 180,
                                          now: start.addingTimeInterval(Double(second))))
            XCTAssertEqual(timer.deadline, deadline)
        }
        XCTAssertTrue(timer.evaluate(capsLockOn: state.requested!, defaultMinutes: 180, now: deadline!))
        state.recordCommand(.changed(to: false))
        state.observe(physical: true) // late keyboard drift cannot undo timer OFF
        XCTAssertEqual(state.requested, false)
    }

    func testConfirmedManualOffWinsOverDriftAndStaleObservations() {
        var state = AwakeSessionState()
        state.recordCommand(.changed(to: true))
        state.observe(physical: false)
        state.recordCommand(.changed(to: false))
        for physical in [true, false, nil] as [Bool?] { state.observe(physical: physical) }
        XCTAssertEqual(state.requested, false)
    }

    func testFailedCommandsDoNotChangeRequestedSession() {
        for active in [false, true] {
            var state = AwakeSessionState()
            state.recordCommand(.changed(to: active))
            for failure in [CapsLockToggleResult.unavailable, .writeFailed(target: !active),
                            .verificationFailed(target: !active, actual: !active)] {
                state.recordCommand(failure)
                XCTAssertEqual(state.requested, active)
            }
        }
    }

    func testPhysicalKeysStillControlTheSession() {
        var state = AwakeSessionState()
        state.observe(physical: false)
        state.recordKey(target: true)
        state.observe(physical: false)
        XCTAssertEqual(state.requested, true)
        state.recordKey(target: false)
        state.observe(physical: true)
        XCTAssertEqual(state.requested, false)
    }

    func testSecureFieldPhysicalOffAndRestoreDoNotEndSession() {
        var state = AwakeSessionState()
        state.recordCommand(.changed(to: true))
        for physical in [false, nil, true, false] as [Bool?] {
            state.observe(physical: physical)
            XCTAssertEqual(state.requested, true)
        }
    }

    func testFilterReportsCapsKeyBeforeSwallowingEvent() throws {
        let filter = DedicatedCapsLockFilter()
        var targets: [Bool] = []
        filter.onCapsLockKey = { target, _ in targets.append(target) }
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 57, keyDown: true))
        event.setIntegerValueField(.keyboardEventKeycode, value: 57)
        event.flags = [.maskAlphaShift]
        XCTAssertNil(filter.handle(type: .flagsChanged, event: event))
        event.flags = []
        XCTAssertNil(filter.handle(type: .flagsChanged, event: event))
        XCTAssertEqual(targets, [true, false])
        event.setIntegerValueField(.keyboardEventKeycode, value: 0)
        event.flags = [.maskAlphaShift, .maskShift]
        XCTAssertNotNil(filter.handle(type: .keyDown, event: event))
        XCTAssertEqual(targets.count, 2)
        XCTAssertFalse(event.flags.contains(.maskAlphaShift))
        XCTAssertTrue(event.flags.contains(.maskShift))
    }
}
