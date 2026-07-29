import XCTest
@testable import Capsomnia

final class BatteryFloorPolicyTests: XCTestCase {
    private func decide(
        intent: Bool = true,
        floorEnabled: Bool = true,
        floor: Int = 15,
        margin: Int = 5,
        onAC: Bool = false,
        percent: Int? = 50,
        batteryReadable: Bool = true,
        latched: Bool = false
    ) -> (keepAwake: Bool, latched: Bool) {
        BatteryFloorPolicy.decide(
            intent: intent,
            floorEnabled: floorEnabled,
            floorPercent: floor,
            recoverMargin: margin,
            onAC: onAC,
            percent: percent,
            batteryReadable: batteryReadable,
            latched: latched
        )
    }

    func testNoIntentNeverKeepsAwakeAndClearsLatch() {
        let result = decide(intent: false, latched: true)
        XCTAssertFalse(result.keepAwake)
        XCTAssertFalse(result.latched)
    }

    func testFloorDisabledKeepsAwakeEvenWhenEmpty() {
        let result = decide(floorEnabled: false, percent: 3)
        XCTAssertTrue(result.keepAwake)
        XCTAssertFalse(result.latched)
    }

    func testUnreadablePowerStaysAwakeAndPreservesLatch() {
        let result = decide(percent: nil, batteryReadable: false, latched: true)
        XCTAssertTrue(result.keepAwake)
        XCTAssertTrue(result.latched)
    }

    func testOnACAlwaysKeepsAwakeAndClearsLatch() {
        let result = decide(onAC: true, percent: 5, latched: true)
        XCTAssertTrue(result.keepAwake)
        XCTAssertFalse(result.latched)
    }

    func testUnknownPercentOnBatteryStaysAwake() {
        let result = decide(percent: nil)
        XCTAssertTrue(result.keepAwake)
    }

    func testAboveFloorKeepsAwake() {
        let result = decide(percent: 16)
        XCTAssertTrue(result.keepAwake)
        XCTAssertFalse(result.latched)
    }

    func testAtFloorReleasesAndLatches() {
        let result = decide(percent: 15)
        XCTAssertFalse(result.keepAwake)
        XCTAssertTrue(result.latched)
    }

    func testBelowFloorReleasesAndLatches() {
        let result = decide(percent: 10)
        XCTAssertFalse(result.keepAwake)
        XCTAssertTrue(result.latched)
    }

    func testHysteresisHoldsBetweenFloorAndRecover() {
        // latched at 17% (> floor 15 but < recover 20) must stay released -> no oscillation
        let result = decide(percent: 17, latched: true)
        XCTAssertFalse(result.keepAwake)
        XCTAssertTrue(result.latched)
    }

    func testHysteresisReleasesAtRecoverThreshold() {
        let result = decide(percent: 20, latched: true)
        XCTAssertTrue(result.keepAwake)
        XCTAssertFalse(result.latched)
    }
}
