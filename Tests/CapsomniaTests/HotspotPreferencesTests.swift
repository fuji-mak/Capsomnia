import XCTest
@testable import Capsomnia

final class HotspotPreferencesTests: XCTestCase {
    func testLegacyDisplayChoiceMigratesOnlyWhenNewChoiceIsAbsentAndIsIdempotent() {
        for (legacy, modern, expected) in [(true, nil, true), (false, nil, false),
                                          (true, false, false), (true, true, true)] as [(Bool, Bool?, Bool)] {
            let domain = "Capsomnia-migration-fixture-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: domain)!
            defer { defaults.removePersistentDomain(forName: domain) }
            defaults.set(legacy, forKey: "DisplaySleepOnLidClose")
            defaults.set("ko", forKey: "Language")
            defaults.set(true, forKey: "KeepHotspotAlive")
            if let modern { defaults.set(modern, forKey: "KeepDisplayAwake") }
            defaults.register(defaults: ["KeepDisplayAwake": false])
            Preferences.migrateLegacyDisplayPreference(defaults, domain: domain)
            XCTAssertEqual(defaults.bool(forKey: "KeepDisplayAwake"), expected)
            Preferences.migrateLegacyDisplayPreference(defaults, domain: domain)
            XCTAssertEqual(defaults.bool(forKey: "KeepDisplayAwake"), expected)
            XCTAssertEqual(defaults.string(forKey: "Language"), "ko")
            XCTAssertTrue(defaults.bool(forKey: "KeepHotspotAlive"))
            if expected {
                defaults.set(false, forKey: "KeepDisplayAwake")
                Preferences.migrateLegacyDisplayPreference(defaults, domain: domain)
                XCTAssertFalse(defaults.bool(forKey: "KeepDisplayAwake"))
            }
        }
    }

    func testFreshInstallDoesNotMigrateAndConfigurationTrimsSSID() {
        let domain = "Capsomnia-migration-fixture-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        Preferences.migrateLegacyDisplayPreference(defaults, domain: domain)
        XCTAssertNil(defaults.persistentDomain(forName: domain)?["KeepDisplayAwake"])
        XCTAssertEqual(HotspotReconnectConfiguration().enabled, false)
        XCTAssertEqual(HotspotReconnectConfiguration(ssid: "  Phone \n").ssid, "Phone")
    }

    func testFastPollingRequiresRawSessionDisplayPreferenceAndKnownClosedLid() {
        for preference in [false, true] {
            for session in [false, true] {
                for lid in [Bool?.none, false, true] {
                    XCTAssertEqual(KeepDisplayAwakePolicy.pollingInterval(preferenceEnabled: preference,
                        capsLockOn: session, lidClosed: lid), preference && session && lid == true ? 0.04 : 0.25)
                }
            }
        }
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
