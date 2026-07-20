import XCTest
@testable import Capsomnia

final class CapsLockControlTests: XCTestCase {
    func testToggleTurnsOffStateOn() {
        var state = false
        let transaction = CapsLockToggleTransaction(
            readState: { state },
            setState: {
                state = $0
                return true
            }
        )

        XCTAssertEqual(transaction.run(), .changed(to: true))
        XCTAssertTrue(state)
    }

    func testToggleTurnsOnStateOff() {
        var state = true
        let transaction = CapsLockToggleTransaction(
            readState: { state },
            setState: {
                state = $0
                return true
            }
        )

        XCTAssertEqual(transaction.run(), .changed(to: false))
        XCTAssertFalse(state)
    }

    func testToggleDoesNotWriteWhenStateCannotBeRead() {
        var didWrite = false
        let transaction = CapsLockToggleTransaction(
            readState: { nil },
            setState: { _ in
                didWrite = true
                return true
            }
        )

        XCTAssertEqual(transaction.run(), .readFailed)
        XCTAssertFalse(didWrite)
    }

    func testToggleReportsWriteFailure() {
        let transaction = CapsLockToggleTransaction(
            readState: { false },
            setState: { _ in false }
        )

        XCTAssertEqual(transaction.run(), .writeFailed(target: true))
    }

    func testToggleReportsVerificationFailure() {
        var readCount = 0
        let transaction = CapsLockToggleTransaction(
            readState: {
                defer { readCount += 1 }
                return false
            },
            setState: { _ in true }
        )

        XCTAssertEqual(
            transaction.run(),
            .verificationFailed(target: true, actual: false)
        )
        XCTAssertEqual(readCount, 2)
    }

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

    func testSystemToggleWhenHardwareTestIsEnabled() throws {
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
            SystemCapsLockController.toggle(),
            .changed(to: !initial)
        )
        XCTAssertEqual(
            stateReader.currentState(),
            !initial
        )

        XCTAssertEqual(
            SystemCapsLockController.toggle(),
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
