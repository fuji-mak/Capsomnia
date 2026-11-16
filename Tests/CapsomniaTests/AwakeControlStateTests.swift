import XCTest
@testable import Capsomnia

final class AwakeControlStateTests: XCTestCase {
    func testOverlappingOperationsStayInFlightUntilEachCompletes() {
        var state = AwakeControlState()
        XCTAssertTrue(state.begin(.manual, target: true))
        XCTAssertTrue(state.begin(.cli, target: true))
        XCTAssertTrue(state.begin(.autoOff, target: false))

        state.finish(.manual, failureState: nil)
        XCTAssertFalse(state.isInFlight(.manual))
        XCTAssertTrue(state.isInFlight(.cli))
        XCTAssertTrue(state.isInFlight(.autoOff))
        XCTAssertTrue(state.isChanging)

        state.finish(.autoOff, failureState: nil)
        XCTAssertTrue(state.isChanging)
        state.finish(.cli, failureState: nil)
        XCTAssertFalse(state.isChanging)
    }

    func testDuplicateRequestDoesNotChangeActiveOperationState() {
        for operation in [AwakeControlState.Operation.manual, .cli, .autoOff] {
            var state = AwakeControlState()
            XCTAssertTrue(state.begin(operation, target: true))
            state.setSecureInputOverrideActive(true)

            XCTAssertFalse(state.begin(operation, target: false))
            XCTAssertTrue(state.isInFlight(operation))
            XCTAssertTrue(state.secureInputCapsLockOverrideActive)
            XCTAssertFalse(state.secureInputOverrideSuppressedForExplicitOff)

            state.finish(operation, failureState: nil)
            XCTAssertFalse(state.isChanging)
            XCTAssertTrue(state.begin(operation, target: false))
        }
    }

    func testExplicitOffPreventsSecureInputRestorationForEveryEntryPoint() {
        for operation in [AwakeControlState.Operation.manual, .cli, .autoOff] {
            var state = AwakeControlState()
            state.setSecureInputOverrideActive(true)
            XCTAssertTrue(state.begin(operation, target: false))
            XCTAssertFalse(state.secureInputCapsLockOverrideActive)
            XCTAssertTrue(state.secureInputOverrideSuppressedForExplicitOff)

            state.finish(operation, failureState: nil)
            state.observePhysicalCapsLock(false)
            XCTAssertTrue(state.secureInputOverrideSuppressedForExplicitOff)
            state.observePhysicalCapsLock(true)
            XCTAssertFalse(state.secureInputOverrideSuppressedForExplicitOff)
        }
    }

    func testExplicitOnAllowsSecureInputOverrideWithoutClearingAnActiveOverride() {
        var state = AwakeControlState()
        XCTAssertTrue(state.begin(.manual, target: false))
        state.finish(.manual, failureState: nil)
        state.setSecureInputOverrideActive(true)

        XCTAssertTrue(state.begin(.cli, target: true))
        XCTAssertFalse(state.secureInputOverrideSuppressedForExplicitOff)
        XCTAssertTrue(state.secureInputCapsLockOverrideActive)
    }

    func testManualAndCLIRequestsClearOldFailureButAutoOffWaitsForItsResult() {
        for operation in [AwakeControlState.Operation.manual, .cli, .autoOff] {
            var state = AwakeControlState()
            XCTAssertTrue(state.begin(.manual, target: false))
            state.finish(.manual, failureState: true)
            XCTAssertEqual(state.failedTogglePhysicalState, true)

            XCTAssertTrue(state.begin(operation, target: false))
            XCTAssertEqual(state.failedTogglePhysicalState, operation == .autoOff ? true : nil)
            state.finish(operation, failureState: nil)
            XCTAssertNil(state.failedTogglePhysicalState)
        }
    }

    func testCLISuccessPreservesFailureFromOverlappingManualOperation() {
        var state = AwakeControlState()
        XCTAssertTrue(state.begin(.cli, target: true))
        XCTAssertTrue(state.begin(.manual, target: false))
        state.finish(.manual, failureState: false)
        XCTAssertEqual(state.failedTogglePhysicalState, false)

        state.finish(.cli, failureState: nil)
        XCTAssertFalse(state.isChanging)
        XCTAssertEqual(state.failedTogglePhysicalState, false)
        state.reconcileToggleFailure(physicalCapsLock: nil)
        XCTAssertEqual(state.failedTogglePhysicalState, false)
        state.reconcileToggleFailure(physicalCapsLock: false)
        XCTAssertEqual(state.failedTogglePhysicalState, false)
        state.reconcileToggleFailure(physicalCapsLock: true)
        XCTAssertNil(state.failedTogglePhysicalState)
    }

    func testFailureRecordsCurrentStateForEveryEntryPoint() {
        for operation in [AwakeControlState.Operation.manual, .cli, .autoOff] {
            var state = AwakeControlState()
            XCTAssertTrue(state.begin(operation, target: false))
            state.finish(operation, failureState: true)
            XCTAssertFalse(state.isChanging)
            XCTAssertEqual(state.failedTogglePhysicalState, true)
        }
    }
}
