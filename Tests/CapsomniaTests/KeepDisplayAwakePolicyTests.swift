import XCTest
@testable import Capsomnia

final class KeepDisplayAwakePolicyTests: XCTestCase {
    func testHoldsAssertionWhenEnabledAndCapsLockOnAndConfirmed() {
        XCTAssertTrue(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: true,
                capsLockOn: true,
                sleepPreventionConfirmed: true
            )
        )
    }

    func testReleasesAssertionWhenCapsLockOff() {
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: true,
                capsLockOn: false,
                sleepPreventionConfirmed: true
            )
        )
    }

    func testReleasesAssertionWhenPreferenceDisabled() {
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: false,
                capsLockOn: true,
                sleepPreventionConfirmed: true
            )
        )
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: false,
                capsLockOn: false,
                sleepPreventionConfirmed: true
            )
        )
    }

    func testReleasesAssertionWhenSleepPreventionUnconfirmed() {
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: true,
                capsLockOn: true,
                sleepPreventionConfirmed: false
            )
        )
    }
}
