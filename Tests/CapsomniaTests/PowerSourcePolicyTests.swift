import XCTest
@testable import Capsomnia

final class PowerSourcePolicyTests: XCTestCase {
    func testRequestedAwakeStaysOnWithACPower() {
        XCTAssertTrue(PowerSourcePolicy.effectiveState(requested: true, source: .ac, disableOnBattery: true))
    }

    func testBatteryLockForcesEffectiveAwakeOff() {
        XCTAssertFalse(PowerSourcePolicy.effectiveState(requested: true, source: .battery, disableOnBattery: true))
        XCTAssertTrue(PowerSourcePolicy.isLocked(source: .battery, disableOnBattery: true))
    }

    func testBatteryPolicyCanBeDisabled() {
        XCTAssertTrue(PowerSourcePolicy.effectiveState(requested: true, source: .battery, disableOnBattery: false))
        XCTAssertFalse(PowerSourcePolicy.isLocked(source: .battery, disableOnBattery: false))
    }

    func testOffRequestRemainsOffAcrossPowerSources() {
        XCTAssertFalse(PowerSourcePolicy.effectiveState(requested: false, source: .ac, disableOnBattery: true))
        XCTAssertFalse(PowerSourcePolicy.effectiveState(requested: false, source: .battery, disableOnBattery: true))
    }
}
