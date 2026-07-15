import XCTest
@testable import Capsomnia

final class CapsLockControllerTests: XCTestCase {
    func testTogglesOnWhenCurrentlyOff() {
        XCTAssertTrue(CapsLockController.toggledState(current: false))
    }

    func testTogglesOffWhenCurrentlyOn() {
        XCTAssertFalse(CapsLockController.toggledState(current: true))
    }
}
