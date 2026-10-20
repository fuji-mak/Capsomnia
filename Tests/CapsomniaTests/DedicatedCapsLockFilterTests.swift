import CoreGraphics
import XCTest
@testable import Capsomnia

final class DedicatedCapsLockFilterTests: XCTestCase {
    func testCapsLockChangesNotifyEvenThoughEventsAreSwallowed() throws {
        let filter = DedicatedCapsLockFilter()
        var notifications = 0
        filter.onCapsLockChange = { notifications += 1 }
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 57, keyDown: true))

        for flags in [CGEventFlags.maskAlphaShift, CGEventFlags()] {
            event.flags = flags
            XCTAssertNil(filter.handle(type: .flagsChanged, event: event))
            XCTAssertFalse(event.flags.contains(.maskAlphaShift))
        }
        XCTAssertEqual(notifications, 2)
    }

    func testOtherKeyboardEventsKeepFilteringWithoutRequestingRefresh() throws {
        let filter = DedicatedCapsLockFilter()
        var notifications = 0
        filter.onCapsLockChange = { notifications += 1 }
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

        for type in [CGEventType.flagsChanged, .keyDown, .keyUp] {
            event.flags = [.maskAlphaShift, .maskShift]
            XCTAssertNotNil(filter.handle(type: type, event: event))
            XCTAssertFalse(event.flags.contains(.maskAlphaShift))
            XCTAssertTrue(event.flags.contains(.maskShift))
        }
        event.setIntegerValueField(.keyboardEventKeycode, value: 57)
        XCTAssertNotNil(filter.handle(type: .keyDown, event: event))
        XCTAssertEqual(notifications, 0)
    }
}
