import XCTest
@testable import Capsomnia

final class ClosedLidDisplayDimmingPolicyTests: XCTestCase {
    func testDimsOnlyWhileConfirmedDisplayAwakeModeIsActiveWithLidClosed() {
        XCTAssertTrue(
            ClosedLidDisplayDimmingPolicy.shouldDim(
                keepDisplayAwake: true,
                capsLockOn: true,
                sleepPreventionConfirmed: true,
                displayAwakeAssertionActive: true,
                clamshellClosed: true
            )
        )

        let inactiveStates: [(Bool, Bool, Bool, Bool, Bool?)] = [
            (false, true, true, true, true),
            (true, false, true, true, true),
            (true, true, false, true, true),
            (true, true, true, false, true),
            (true, true, true, true, false),
            (true, true, true, true, nil)
        ]
        for state in inactiveStates {
            XCTAssertFalse(
                ClosedLidDisplayDimmingPolicy.shouldDim(
                    keepDisplayAwake: state.0,
                    capsLockOn: state.1,
                    sleepPreventionConfirmed: state.2,
                    displayAwakeAssertionActive: state.3,
                    clamshellClosed: state.4
                )
            )
        }
    }
}

final class ClosedLidDisplayDimmingControllerTests: XCTestCase {
    func testDimsOnceAndRestoresExactPreviousBrightness() {
        var reads = 0
        var writes: [Float] = []
        let controller = ClosedLidDisplayDimmingController(
            readBrightness: {
                reads += 1
                return 0.73
            },
            writeBrightness: {
                writes.append($0)
                return true
            }
        )

        XCTAssertTrue(controller.setDimmed(true))
        XCTAssertTrue(controller.setDimmed(true))
        XCTAssertTrue(controller.isDimmed)
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(writes, [0])

        XCTAssertTrue(controller.setDimmed(false))
        XCTAssertTrue(controller.setDimmed(false))
        XCTAssertFalse(controller.isDimmed)
        XCTAssertEqual(writes, [0, 0.73])
    }

    func testFailedDimDoesNotClaimDisplayIsDimmed() {
        var persisted: [Float?] = []
        let controller = ClosedLidDisplayDimmingController(
            readBrightness: { 0.5 },
            writeBrightness: { _ in false },
            persistBrightness: { persisted.append($0) }
        )

        XCTAssertFalse(controller.setDimmed(true))
        XCTAssertFalse(controller.isDimmed)
        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(persisted[0], 0.5)
        XCTAssertNil(persisted[1])
    }

    func testFailedRestoreKeepsBrightnessForRetry() {
        var writes: [Float] = []
        var shouldSucceed = true
        let controller = ClosedLidDisplayDimmingController(
            readBrightness: { 0.42 },
            writeBrightness: {
                writes.append($0)
                return shouldSucceed
            }
        )

        XCTAssertTrue(controller.setDimmed(true))
        shouldSucceed = false
        XCTAssertFalse(controller.setDimmed(false))
        XCTAssertTrue(controller.isDimmed)

        shouldSucceed = true
        XCTAssertTrue(controller.setDimmed(false))
        XCTAssertFalse(controller.isDimmed)
        XCTAssertEqual(writes, [0, 0.42, 0.42])
    }

    func testZeroBrightnessStillTracksDimmedState() {
        var writes: [Float] = []
        let controller = ClosedLidDisplayDimmingController(
            readBrightness: { 0 },
            writeBrightness: {
                writes.append($0)
                return true
            }
        )

        XCTAssertTrue(controller.setDimmed(true))
        XCTAssertTrue(controller.isDimmed)
        XCTAssertTrue(controller.setDimmed(false))
        XCTAssertFalse(controller.isDimmed)
        XCTAssertEqual(writes, [0, 0])
    }

    func testRestoresPersistedBrightnessFromAnEarlierProcess() {
        var writes: [Float] = []
        var persisted: [Float?] = []
        let controller = ClosedLidDisplayDimmingController(
            readBrightness: { XCTFail("Recovery must not replace the saved value"); return nil },
            writeBrightness: {
                writes.append($0)
                return true
            },
            loadSavedBrightness: { 0.61 },
            persistBrightness: { persisted.append($0) }
        )

        XCTAssertTrue(controller.isDimmed)
        XCTAssertTrue(controller.setDimmed(false))
        XCTAssertFalse(controller.isDimmed)
        XCTAssertEqual(writes, [0.61])
        XCTAssertEqual(persisted.count, 1)
        XCTAssertNil(persisted[0])
    }
}
