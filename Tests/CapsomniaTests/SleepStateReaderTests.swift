import CoreGraphics
import XCTest
@testable import Capsomnia

final class SleepStateReaderTests: XCTestCase {
    func testParsesDisabledState() {
        let output = """
        System-wide power settings:
         SleepDisabled        1
        """

        XCTAssertEqual(SleepStateReader.parse(output), true)
    }

    func testParsesNormalState() {
        let output = """
        System-wide power settings:
         SleepDisabled        0
        """

        XCTAssertEqual(SleepStateReader.parse(output), false)
    }

    func testRejectsMissingOrUnexpectedState() {
        XCTAssertNil(SleepStateReader.parse("System-wide power settings:"))
        XCTAssertNil(SleepStateReader.parse("SleepDisabled 2"))
    }
}

final class DisplaySleepPolicyTests: XCTestCase {
    func testAllowsDisplaySleepWithoutExternalDisplay() {
        XCTAssertTrue(DisplaySleepPolicy.shouldRequestDisplaySleep(externalDisplayConnected: false))
    }

    func testSuppressesDisplaySleepWithExternalDisplay() {
        XCTAssertFalse(DisplaySleepPolicy.shouldRequestDisplaySleep(externalDisplayConnected: true))
    }

    func testSuppressesDisplaySleepWhenDisplayStateIsUnavailable() {
        XCTAssertFalse(DisplaySleepPolicy.shouldRequestDisplaySleep(externalDisplayConnected: nil))
    }
}

final class DedicatedCapsLockEventPolicyTests: XCTestCase {
    func testRemovesCapsLockFlagAndPreservesOtherModifiers() {
        let flags: CGEventFlags = [.maskAlphaShift, .maskShift, .maskCommand]

        let sanitized = DedicatedCapsLockEventPolicy.sanitizedFlags(flags)

        XCTAssertFalse(sanitized.contains(.maskAlphaShift))
        XCTAssertTrue(sanitized.contains(.maskShift))
        XCTAssertTrue(sanitized.contains(.maskCommand))
    }

    func testSuppressesOnlyCapsLockFlagsChangedEvent() {
        XCTAssertTrue(
            DedicatedCapsLockEventPolicy.shouldSuppress(
                eventType: .flagsChanged,
                keyCode: DedicatedCapsLockEventPolicy.capsLockKeyCode
            )
        )
        XCTAssertFalse(
            DedicatedCapsLockEventPolicy.shouldSuppress(
                eventType: .keyDown,
                keyCode: DedicatedCapsLockEventPolicy.capsLockKeyCode
            )
        )
        XCTAssertFalse(
            DedicatedCapsLockEventPolicy.shouldSuppress(
                eventType: .flagsChanged,
                keyCode: 56
            )
        )
    }
}

final class DedicatedCapsLockReadinessPolicyTests: XCTestCase {
    func testRequiresActiveFilterOnlyWhenDedicatedModeIsEnabled() {
        XCTAssertTrue(
            DedicatedCapsLockReadinessPolicy.shouldHonorCapsLock(
                dedicatedModeEnabled: false,
                filterActive: false
            )
        )
        XCTAssertTrue(
            DedicatedCapsLockReadinessPolicy.shouldHonorCapsLock(
                dedicatedModeEnabled: true,
                filterActive: true
            )
        )
        XCTAssertFalse(
            DedicatedCapsLockReadinessPolicy.shouldHonorCapsLock(
                dedicatedModeEnabled: true,
                filterActive: false
            )
        )
    }
}
