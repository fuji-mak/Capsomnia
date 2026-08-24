import XCTest
@testable import Capsomnia

final class UpdateCheckTests: XCTestCase {
    func testVersionComparisonOrdersNumericComponents() {
        XCTAssertTrue(UpdateCheck.isVersion("3.5.0", newerThan: "3.4.0"))
        XCTAssertTrue(UpdateCheck.isVersion("4.0.0", newerThan: "3.9.9"))
        XCTAssertTrue(UpdateCheck.isVersion("3.4.10", newerThan: "3.4.9"))
        XCTAssertFalse(UpdateCheck.isVersion("3.4.0", newerThan: "3.4.0"))
        XCTAssertFalse(UpdateCheck.isVersion("3.4.0", newerThan: "3.5.0"))
    }

    func testVersionComparisonHandlesDifferentComponentCounts() {
        XCTAssertTrue(UpdateCheck.isVersion("3.4.1", newerThan: "3.4"))
        XCTAssertFalse(UpdateCheck.isVersion("3.4", newerThan: "3.4.0"))
        XCTAssertTrue(UpdateCheck.isVersion("3.5", newerThan: "3.4.9"))
    }

    func testVersionComparisonRejectsNonNumericVersions() {
        XCTAssertFalse(UpdateCheck.isVersion("abc", newerThan: "3.4.0"))
        XCTAssertFalse(UpdateCheck.isVersion("3.5.0", newerThan: "abc"))
        XCTAssertFalse(UpdateCheck.isVersion("", newerThan: "3.4.0"))
        XCTAssertFalse(UpdateCheck.isVersion("3.5.0", newerThan: ""))
    }

    func testVersionFromTagStripsLeadingV() {
        XCTAssertEqual(UpdateCheck.version(fromTag: "v3.5.0"), "3.5.0")
        XCTAssertEqual(UpdateCheck.version(fromTag: "3.5.0"), "3.5.0")
    }

    func testParseLatestReleaseReadsTagName() {
        let payload = Data("""
        {"tag_name": "v3.5.0", "name": "Capsomnia 3.5.0", "draft": false, "prerelease": false}
        """.utf8)

        XCTAssertEqual(UpdateCheck.parseLatestReleaseVersion(payload), "3.5.0")
    }

    func testParseLatestReleaseRejectsInvalidPayloads() {
        XCTAssertNil(UpdateCheck.parseLatestReleaseVersion(Data("{}".utf8)))
        XCTAssertNil(UpdateCheck.parseLatestReleaseVersion(Data("not json".utf8)))
        XCTAssertNil(UpdateCheck.parseLatestReleaseVersion(Data()))
    }

    func testShouldAutoCheckAfterIntervalElapses() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let day: TimeInterval = 86_400

        XCTAssertTrue(UpdateCheck.shouldAutoCheck(now: now, lastCheckedAt: nil, minimumInterval: day))
        XCTAssertTrue(UpdateCheck.shouldAutoCheck(now: now, lastCheckedAt: now.addingTimeInterval(-day), minimumInterval: day))
        XCTAssertFalse(UpdateCheck.shouldAutoCheck(now: now, lastCheckedAt: now.addingTimeInterval(-day + 60), minimumInterval: day))
    }

    func testShouldAutoCheckRecoversFromFutureLastCheckDate() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        XCTAssertTrue(UpdateCheck.shouldAutoCheck(now: now, lastCheckedAt: now.addingTimeInterval(3_600), minimumInterval: 86_400))
    }

    func testInstallerCleanupWithoutRecordDoesNothing() {
        let action = UpdateCheck.installerCleanupAction(
            currentVersion: "3.5.0",
            recordedPath: nil,
            recordedVersion: nil,
            fileExists: { _ in true }
        )

        XCTAssertEqual(action, .none)
    }

    func testInstallerCleanupOffersRemovalOnceUpdateIsInstalled() {
        let action = UpdateCheck.installerCleanupAction(
            currentVersion: "3.5.0",
            recordedPath: "/Users/test/Downloads/Capsomnia-3.5.0.pkg",
            recordedVersion: "3.5.0",
            fileExists: { _ in true }
        )

        XCTAssertEqual(action, .offerRemoval(path: "/Users/test/Downloads/Capsomnia-3.5.0.pkg", version: "3.5.0"))
    }

    func testInstallerCleanupWaitsWhileUpdateIsStillPending() {
        let action = UpdateCheck.installerCleanupAction(
            currentVersion: "3.4.0",
            recordedPath: "/Users/test/Downloads/Capsomnia-3.5.0.pkg",
            recordedVersion: "3.5.0",
            fileExists: { _ in true }
        )

        XCTAssertEqual(action, .keepWaiting)
    }

    func testAutomaticUpdateChecksDefaultsToOn() {
        let previous = UserDefaults.standard.object(forKey: "AutomaticUpdateChecks")
        UserDefaults.standard.removeObject(forKey: "AutomaticUpdateChecks")
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: "AutomaticUpdateChecks")
            }
        }
        Preferences.registerDefaults()

        XCTAssertTrue(Preferences.automaticUpdateChecks)

        Preferences.automaticUpdateChecks = false
        XCTAssertFalse(Preferences.automaticUpdateChecks)
        UserDefaults.standard.removeObject(forKey: "AutomaticUpdateChecks")
    }

    func testPendingInstallerRecordRoundTripsAndClears() {
        let previousPath = Preferences.pendingInstallerPath
        let previousVersion = Preferences.pendingInstallerVersion
        defer {
            Preferences.setPendingInstaller(path: previousPath, version: previousVersion)
        }

        Preferences.setPendingInstaller(path: "/tmp/Capsomnia-9.9.9.pkg", version: "9.9.9")
        XCTAssertEqual(Preferences.pendingInstallerPath, "/tmp/Capsomnia-9.9.9.pkg")
        XCTAssertEqual(Preferences.pendingInstallerVersion, "9.9.9")

        Preferences.setPendingInstaller(path: nil, version: nil)
        XCTAssertNil(Preferences.pendingInstallerPath)
        XCTAssertNil(Preferences.pendingInstallerVersion)
    }

    func testLastUpdateCheckDateRoundTrips() {
        let previous = Preferences.lastUpdateCheckAt
        defer { Preferences.lastUpdateCheckAt = previous }

        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        Preferences.lastUpdateCheckAt = date
        XCTAssertEqual(Preferences.lastUpdateCheckAt, date)
    }

    func testInstallerCleanupClearsRecordWhenFileIsGone() {
        let action = UpdateCheck.installerCleanupAction(
            currentVersion: "3.5.0",
            recordedPath: "/Users/test/Downloads/Capsomnia-3.5.0.pkg",
            recordedVersion: "3.5.0",
            fileExists: { _ in false }
        )

        XCTAssertEqual(action, .clearRecord)
    }
}
