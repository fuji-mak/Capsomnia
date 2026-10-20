import XCTest
@testable import Capsomnia

final class ManualCapsLockOffConfirmationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100)

    func testPhysicalOffCanSkipDebounceOnlyOnceAfterPress() {
        var confirmation = ManualCapsLockOffConfirmation()
        XCTAssertFalse(confirmation.consume(physicalCapsLockOn: false, now: now))
        confirmation.begin(now: now, validFor: 0.5)
        XCTAssertTrue(confirmation.consume(physicalCapsLockOn: false, now: now))
        XCTAssertFalse(confirmation.consume(physicalCapsLockOn: false, now: now))
    }

    func testWaitsForActualOffIfHIDArrivesBeforeStateChange() {
        var confirmation = ManualCapsLockOffConfirmation()
        confirmation.begin(now: now, validFor: 0.5)
        XCTAssertFalse(confirmation.consume(physicalCapsLockOn: true, now: now))
        XCTAssertTrue(confirmation.consume(
            physicalCapsLockOn: false, now: now.addingTimeInterval(0.1)
        ))
    }

    func testUnrelatedOffAfterExpiryCannotUseAnOldPress() {
        var confirmation = ManualCapsLockOffConfirmation()
        confirmation.begin(now: now, validFor: 0.5)
        XCTAssertFalse(confirmation.consume(
            physicalCapsLockOn: false, now: now.addingTimeInterval(0.5)
        ))
    }

    func testInputSwitchOrExplicitCommandCanCancelConfirmation() {
        var confirmation = ManualCapsLockOffConfirmation()
        confirmation.begin(now: now, validFor: 0.5)
        confirmation.cancel()
        XCTAssertFalse(confirmation.consume(
            physicalCapsLockOn: false, now: now.addingTimeInterval(0.1)
        ))
    }
}
