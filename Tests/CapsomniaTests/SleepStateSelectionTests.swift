import XCTest
@testable import Capsomnia

final class SleepStateSelectionTests: XCTestCase {
    func testManualChoiceSurvivesUnchangedHardwarePolls() {
        var selection = SleepStateSelection()
        _ = selection.observeHardwareState(false)
        selection.setManualOverride(true)

        XCTAssertTrue(selection.observeHardwareState(false).sleepPreventionOn)
        XCTAssertTrue(selection.observeHardwareState(false).sleepPreventionOn)
    }

    func testHardwareTransitionClearsManualChoice() {
        var selection = SleepStateSelection()
        _ = selection.observeHardwareState(false)
        selection.setManualOverride(false)

        let resolution = selection.observeHardwareState(true)

        XCTAssertTrue(resolution.sleepPreventionOn)
        XCTAssertTrue(resolution.clearedManualOverride)
        XCTAssertNil(selection.manualOverride)
    }
}
