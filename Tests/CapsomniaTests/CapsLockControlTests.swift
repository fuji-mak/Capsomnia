import XCTest
@testable import Capsomnia

final class CapsLockControlTests: XCTestCase {
    func testConfirmationRequiresConsecutiveMatches() {
        var states: [Bool?] = [true, false, true, true, true]
        var waitCount = 0
        let confirmation = CapsLockStateConfirmation(
            readState: { states.removeFirst() },
            wait: { waitCount += 1 },
            maximumAttempts: 5,
            requiredConsecutiveMatches: 3
        )

        XCTAssertEqual(
            confirmation.confirm(target: true),
            CapsLockStateConfirmationResult(confirmed: true, actual: true)
        )
        XCTAssertEqual(waitCount, 4)
    }

    func testConfirmationReportsLastObservedStateOnTimeout() {
        var states: [Bool?] = [false, nil, false]
        let confirmation = CapsLockStateConfirmation(
            readState: { states.removeFirst() },
            wait: {},
            maximumAttempts: 3,
            requiredConsecutiveMatches: 2
        )

        XCTAssertEqual(
            confirmation.confirm(target: true),
            CapsLockStateConfirmationResult(confirmed: false, actual: false)
        )
    }

    func testSystemSetRoundTripWhenHardwareTestIsEnabled() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CAPSOMNIA_HARDWARE_TEST"] == "1",
            "Set CAPSOMNIA_HARDWARE_TEST=1 to exercise the real Caps Lock state."
        )

        let stateReader = SystemCapsLockStateReader()
        guard let initial = stateReader.currentState() else {
            XCTFail("Could not read the initial IOHID Caps Lock state.")
            return
        }
        defer {
            _ = SystemCapsLockController.set(initial)
        }

        XCTAssertEqual(
            SystemCapsLockController.set(!initial),
            .changed(to: !initial)
        )
        XCTAssertEqual(
            stateReader.currentState(),
            !initial
        )

        XCTAssertEqual(
            SystemCapsLockController.set(initial),
            .changed(to: initial)
        )
        XCTAssertEqual(
            stateReader.currentState(),
            initial
        )
    }

    func testSystemSetWhenHardwareTargetIsProvided() throws {
        guard let rawTarget = ProcessInfo.processInfo.environment["CAPSOMNIA_HARDWARE_TARGET"] else {
            throw XCTSkip("Set CAPSOMNIA_HARDWARE_TARGET=on or off to exercise an explicit state.")
        }
        guard rawTarget == "on" || rawTarget == "off" else {
            XCTFail("CAPSOMNIA_HARDWARE_TARGET must be on or off.")
            return
        }

        let target = rawTarget == "on"
        XCTAssertEqual(
            SystemCapsLockController.set(target),
            .changed(to: target)
        )
        XCTAssertEqual(
            SystemCapsLockStateReader().currentState(),
            target
        )
    }
}
