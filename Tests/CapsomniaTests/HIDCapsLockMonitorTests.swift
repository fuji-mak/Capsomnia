import XCTest
@testable import Capsomnia

final class HIDCapsLockMonitorTests: XCTestCase {
    func testPressOnlyFiresOnceUntilRelease() {
        var tracker = HIDCapsLockPressTracker()
        XCTAssertTrue(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 1))
        XCTAssertFalse(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 1))
        XCTAssertFalse(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 0))
        XCTAssertTrue(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 1))
    }

    func testInputSourceKeysAndLEDReportsAreNotCapsLockPresses() {
        var tracker = HIDCapsLockPressTracker()
        XCTAssertFalse(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x90, value: 1))
        XCTAssertFalse(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x91, value: 1))
        XCTAssertFalse(tracker.handle(deviceID: 1, usagePage: 8, usage: 2, value: 1))
        XCTAssertFalse(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: -1))
        XCTAssertTrue(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 1))
    }

    func testKeyboardsAreIndependentAndRemovalClearsPressedState() {
        var tracker = HIDCapsLockPressTracker()
        XCTAssertTrue(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 1))
        XCTAssertTrue(tracker.handle(deviceID: 2, usagePage: 7, usage: 0x39, value: 1))
        tracker.removeDevice(1)
        XCTAssertTrue(tracker.handle(deviceID: 1, usagePage: 7, usage: 0x39, value: 1))
        XCTAssertFalse(tracker.handle(deviceID: 2, usagePage: 7, usage: 0x39, value: 1))
    }
}
