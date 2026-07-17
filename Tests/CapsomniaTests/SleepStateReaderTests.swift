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
