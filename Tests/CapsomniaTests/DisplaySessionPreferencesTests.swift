import XCTest
@testable import Capsomnia

final class DisplaySessionPreferencesTests: XCTestCase {
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


    func testFreshInstallDoesNotMigrate() {
        let domain = "Capsomnia-migration-fixture-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        Preferences.migrateLegacyDisplayPreference(defaults, domain: domain)
        XCTAssertNil(defaults.persistentDomain(forName: domain)?["KeepDisplayAwake"])
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

}
