import XCTest
@testable import Capsomnia

final class ExternalCapsLockOffPolicyTests: XCTestCase {
    func testReassertsWhenLidClosedWithoutUserAction() {
        XCTAssertTrue(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: true,
                sleepPreventionActive: true,
                recentUserAction: false,
                autoOffInProgress: false,
                clamshellClosed: true
            )
        )
    }

    func testHonorsTurnOffWhenPreferenceDisabled() {
        XCTAssertFalse(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: false,
                sleepPreventionActive: true,
                recentUserAction: false,
                autoOffInProgress: false,
                clamshellClosed: true
            )
        )
    }

    func testHonorsTurnOffAfterRecentUserAction() {
        XCTAssertFalse(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: true,
                sleepPreventionActive: true,
                recentUserAction: true,
                autoOffInProgress: false,
                clamshellClosed: true
            )
        )
    }

    func testHonorsTurnOffWhileAutoOffInProgress() {
        XCTAssertFalse(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: true,
                sleepPreventionActive: true,
                recentUserAction: false,
                autoOffInProgress: true,
                clamshellClosed: true
            )
        )
    }

    func testHonorsTurnOffWhenLidOpen() {
        XCTAssertFalse(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: true,
                sleepPreventionActive: true,
                recentUserAction: false,
                autoOffInProgress: false,
                clamshellClosed: false
            )
        )
    }

    func testHonorsTurnOffWhenClamshellStateUnavailable() {
        XCTAssertFalse(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: true,
                sleepPreventionActive: true,
                recentUserAction: false,
                autoOffInProgress: false,
                clamshellClosed: nil
            )
        )
    }

    func testHonorsTurnOffWhenSleepPreventionInactive() {
        XCTAssertFalse(
            ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: true,
                sleepPreventionActive: false,
                recentUserAction: false,
                autoOffInProgress: false,
                clamshellClosed: true
            )
        )
    }
}
