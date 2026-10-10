import IOKit
import XCTest
@testable import Capsomnia

final class DisplayAwakeAssertionTests: XCTestCase {
    private func makeAssertion(
        create: @escaping (UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn,
        release: @escaping (IOPMAssertionID) -> IOReturn
    ) -> DisplayAwakeAssertion {
        DisplayAwakeAssertion(create: create, release: release, declareActivity: { id in
            id.pointee = 11
            return kIOReturnSuccess
        }, scheduleHeartbeat: { _ in {} })
    }

    func testCreatesAndReleasesAssertion() {
        var releasedIDs: [IOPMAssertionID] = []
        let assertion = makeAssertion(
            create: { id in
                id.pointee = 7
                return kIOReturnSuccess
            },
            release: { id in
                releasedIDs.append(id)
                return kIOReturnSuccess
            }
        )

        XCTAssertTrue(assertion.setActive(true))
        XCTAssertTrue(assertion.isActive)
        XCTAssertTrue(assertion.setActive(false))
        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(releasedIDs, [7, 11])
    }

    func testSetActiveIsIdempotent() {
        var createCount = 0
        let assertion = makeAssertion(
            create: { id in
                createCount += 1
                id.pointee = 7
                return kIOReturnSuccess
            },
            release: { _ in kIOReturnSuccess }
        )

        XCTAssertTrue(assertion.setActive(true))
        XCTAssertTrue(assertion.setActive(true))
        XCTAssertEqual(createCount, 1)
        XCTAssertTrue(assertion.setActive(false))
        XCTAssertTrue(assertion.setActive(false))
    }

    func testFailedCreateReportsFailure() {
        let assertion = makeAssertion(
            create: { _ in kIOReturnInternalError },
            release: { _ in kIOReturnSuccess }
        )

        XCTAssertFalse(assertion.setActive(true))
        XCTAssertFalse(assertion.isActive)
    }

    func testTransientReleaseFailureKeepsAssertionForRetry() {
        var releaseResults: [IOReturn] = [kIOReturnInternalError, kIOReturnSuccess, kIOReturnSuccess]
        var releasedIDs: [IOPMAssertionID] = []
        let assertion = makeAssertion(
            create: { id in
                id.pointee = 7
                return kIOReturnSuccess
            },
            release: { id in
                releasedIDs.append(id)
                return releaseResults.removeFirst()
            }
        )

        XCTAssertTrue(assertion.setActive(true))
        XCTAssertFalse(assertion.setActive(false))
        XCTAssertTrue(assertion.isActive, "A transient failure should keep the ID for retry")
        XCTAssertTrue(assertion.setActive(false))
        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(releasedIDs, [7, 11, 7], "The retry should release the same ID")
    }

    func testStaleAssertionIDIsDropped() {
        for staleStatus in [kIOReturnBadArgument, kIOReturnNotPermitted] {
            let assertion = makeAssertion(
                create: { id in
                    id.pointee = 7
                    return kIOReturnSuccess
                },
                release: { _ in staleStatus }
            )

            XCTAssertTrue(assertion.setActive(true))
            XCTAssertTrue(
                assertion.setActive(false),
                "A stale ID holds nothing for this instance, so the release goal is already met"
            )
            XCTAssertFalse(assertion.isActive)
            XCTAssertTrue(assertion.setActive(true), "Re-enabling must create a fresh assertion")
            XCTAssertTrue(assertion.isActive)
        }
    }
    func testHeartbeatRetriesAndStopsBeforeRelease() {
        var pulse: (() -> Void)?
        var scheduled = 0
        var stopped = false
        var declarations = 0
        var results: [IOReturn] = [kIOReturnInternalError, kIOReturnSuccess, kIOReturnSuccess]
        var released: [IOPMAssertionID] = []
        let assertion = DisplayAwakeAssertion(create: { id in
            id.pointee = 7
            return kIOReturnSuccess
        }, release: { id in
            XCTAssertTrue(stopped)
            released.append(id)
            return kIOReturnSuccess
        }, declareActivity: { id in
            declarations += 1
            id.pointee = 11
            return results.removeFirst()
        }, scheduleHeartbeat: { action in
            scheduled += 1
            pulse = action
            return { stopped = true; pulse = nil }
        })
        XCTAssertFalse(assertion.setActive(true))
        XCTAssertTrue(assertion.isActive)
        XCTAssertFalse(assertion.isHealthy)
        XCTAssertTrue(assertion.setActive(true))
        XCTAssertEqual(scheduled, 1)
        pulse?()
        XCTAssertEqual(declarations, 3)
        XCTAssertTrue(assertion.setActive(false))
        XCTAssertNil(pulse)
        XCTAssertEqual(released, [7, 11])
    }

    func testExpiredHeartbeatAssertionIsRecreatedOnRetry() {
        var pulse: (() -> Void)?
        var suppliedIDs: [IOPMAssertionID] = []
        let assertion = DisplayAwakeAssertion(create: { id in
            id.pointee = 7
            return kIOReturnSuccess
        }, release: { _ in kIOReturnSuccess }, declareActivity: { id in
            suppliedIDs.append(id.pointee)
            if suppliedIDs.count == 2 { return kIOReturnBadArgument }
            id.pointee = 11
            return kIOReturnSuccess
        }, scheduleHeartbeat: { action in pulse = action; return { pulse = nil } })
        XCTAssertTrue(assertion.setActive(true))
        pulse?()
        XCTAssertFalse(assertion.isHealthy)
        XCTAssertTrue(assertion.setActive(true))
        XCTAssertEqual(suppliedIDs, [0, 11, 0])
        XCTAssertTrue(assertion.setActive(false))
    }

}
