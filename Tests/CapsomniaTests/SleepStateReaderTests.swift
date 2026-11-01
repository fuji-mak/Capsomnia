import CoreGraphics
import XCTest
@testable import Capsomnia

final class SleepStateReaderTests: XCTestCase {
    @MainActor
    func testIsDisabledDoesNotRunMainRunLoopCallbacks() {
        var timerDidFire = false
        let timer = Timer(timeInterval: 0.01, repeats: false) { _ in
            timerDidFire = true
        }
        RunLoop.main.add(timer, forMode: .default)
        defer { timer.invalidate() }

        _ = SleepStateReader.isDisabled()

        XCTAssertFalse(timerDidFire)
    }

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
        XCTAssertTrue(
            DisplaySleepPolicy.shouldRequestDisplaySleep(
                keepDisplayAwake: false,
                externalDisplayConnected: false
            )
        )
    }

    func testSuppressesDisplaySleepWithExternalDisplay() {
        XCTAssertFalse(
            DisplaySleepPolicy.shouldRequestDisplaySleep(
                keepDisplayAwake: false,
                externalDisplayConnected: true
            )
        )
    }

    func testSuppressesDisplaySleepWhenDisplayStateIsUnavailable() {
        XCTAssertFalse(
            DisplaySleepPolicy.shouldRequestDisplaySleep(
                keepDisplayAwake: false,
                externalDisplayConnected: nil
            )
        )
    }

    func testSuppressesLidCloseDisplaySleepWhileKeepingDisplayAwake() {
        XCTAssertFalse(
            DisplaySleepPolicy.shouldRequestDisplaySleep(
                keepDisplayAwake: true,
                externalDisplayConnected: false
            )
        )
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
