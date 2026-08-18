import IOKit
import XCTest
@testable import Capsomnia

final class DisplayAwakeAssertionTests: XCTestCase {
    func testCreatesAndReleasesAssertion() {
        var releasedIDs: [IOPMAssertionID] = []
        let assertion = DisplayAwakeAssertion(
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
        XCTAssertEqual(releasedIDs, [7])
    }

    func testSetActiveIsIdempotent() {
        var createCount = 0
        let assertion = DisplayAwakeAssertion(
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
        let assertion = DisplayAwakeAssertion(
            create: { _ in kIOReturnInternalError },
            release: { _ in kIOReturnSuccess }
        )

        XCTAssertFalse(assertion.setActive(true))
        XCTAssertFalse(assertion.isActive)
    }

    func testTransientReleaseFailureKeepsAssertionForRetry() {
        var releaseResults: [IOReturn] = [kIOReturnInternalError, kIOReturnSuccess]
        var releasedIDs: [IOPMAssertionID] = []
        let assertion = DisplayAwakeAssertion(
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
        XCTAssertEqual(releasedIDs, [7, 7], "The retry should release the same ID")
    }

    func testStaleAssertionIDIsDropped() {
        let assertion = DisplayAwakeAssertion(
            create: { id in
                id.pointee = 7
                return kIOReturnSuccess
            },
            release: { _ in kIOReturnBadArgument }
        )

        XCTAssertTrue(assertion.setActive(true))
        XCTAssertTrue(
            assertion.setActive(false),
            "A stale ID names no assertion, so the release goal is already met"
        )
        XCTAssertFalse(assertion.isActive)
        XCTAssertTrue(assertion.setActive(true), "Re-enabling must create a fresh assertion")
        XCTAssertTrue(assertion.isActive)
    }
}
