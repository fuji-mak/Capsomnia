import XCTest
@testable import Capsomnia

final class HotspotPreferencesTests: XCTestCase {
    func testConfigurationDefaultsToDisabledAndTrimsSSID() {
        XCTAssertEqual(HotspotReconnectConfiguration().enabled, false)
        XCTAssertEqual(HotspotReconnectConfiguration(ssid: "  Phone \n").ssid, "Phone")
    }

    func testHotspotLabelsAndStatusesAreLocalizedForAllLanguages() {
        let statuses: [HotspotReconnectStatus] = [.disabled, .sessionInactive, .needsSSID, .ready, .waiting,
            .joining, .needsLocation, .passwordMissing, .passwordUnreadable, .targetNotVisible,
            .interfaceUnavailable, .associationFailed]
        for language in AppLanguage.allCases {
            let strings = HotspotStrings.localized(for: language)
            XCTAssertFalse(strings.title.isEmpty)
            XCTAssertFalse(strings.password.isEmpty)
            XCTAssertTrue(strings.instantHotspot.contains("26"))
            for status in statuses {
                XCTAssertFalse(strings.status(status).isEmpty)
                if language != .english {
                    XCTAssertNotEqual(strings.status(status), HotspotStrings.localized(for: .english).status(status))
                }
            }
        }
    }
}
