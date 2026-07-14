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

    func testParsesWhitespaceAndCaseBoundaries() {
        XCTAssertEqual(SleepStateReader.parse("\r\n\t sleepdisabled\t1\r\n"), true)
        XCTAssertEqual(SleepStateReader.parse("  SLEEPDISABLED  0  "), false)
    }

    func testRejectsIncompleteOrNonNumericSleepState() {
        XCTAssertNil(SleepStateReader.parse("SleepDisabled"))
        XCTAssertNil(SleepStateReader.parse("SleepDisabled true"))
        XCTAssertNil(SleepStateReader.parse("OtherSleepDisabled 1"))
    }

    func testLogRotationThreshold() {
        XCTAssertFalse(LogFileRotation.shouldRotate(
            currentSize: LogFileRotation.maximumSize - 8,
            incomingDataSize: 8
        ))
        XCTAssertTrue(LogFileRotation.shouldRotate(
            currentSize: LogFileRotation.maximumSize - 8,
            incomingDataSize: 9
        ))
    }

    func testMasterEnableDirectlyControlsKeepRunning() {
        XCTAssertFalse(SleepControlPolicy.shouldDisableSleep(enabled: false))
        XCTAssertTrue(SleepControlPolicy.shouldDisableSleep(enabled: true))
    }

}
