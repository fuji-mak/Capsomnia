import XCTest
@testable import Capsomnia

final class KeepDisplayAwakePolicyTests: XCTestCase {
    func testHoldsAssertionWhenEnabledAndCapsLockOn() {
        XCTAssertTrue(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: true,
                capsLockOn: true
            )
        )
    }

    func testReleasesAssertionWhenCapsLockOff() {
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: true,
                capsLockOn: false
            )
        )
    }

    func testReleasesAssertionWhenPreferenceDisabled() {
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: false,
                capsLockOn: true
            )
        )
        XCTAssertFalse(
            KeepDisplayAwakePolicy.shouldHoldAssertion(
                preferenceEnabled: false,
                capsLockOn: false
            )
        )
    }
}
