import Foundation
import XCTest
@testable import Capsomnia

final class CapsLockIndicatorFeatureFlagTests: XCTestCase {
    private func plistData(_ plist: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
    }

    func testMissingPlistMeansIndicatorIsShown() {
        XCTAssertFalse(CapsLockIndicatorFeatureFlag.isHidden(plistData: nil))
    }

    func testDisabledFlagMeansIndicatorIsHidden() throws {
        let data = try plistData([
            "redesigned_text_cursor": ["Enabled": false]
        ])

        XCTAssertTrue(CapsLockIndicatorFeatureFlag.isHidden(plistData: data))
    }

    func testEnabledFlagMeansIndicatorIsShown() throws {
        let data = try plistData([
            "redesigned_text_cursor": ["Enabled": true]
        ])

        XCTAssertFalse(CapsLockIndicatorFeatureFlag.isHidden(plistData: data))
    }

    func testUnrelatedFlagsMeanIndicatorIsShown() throws {
        let data = try plistData([
            "some_other_flag": ["Enabled": false]
        ])

        XCTAssertFalse(CapsLockIndicatorFeatureFlag.isHidden(plistData: data))
    }

    func testMalformedPlistMeansIndicatorIsShown() {
        let data = Data("not a plist".utf8)

        XCTAssertFalse(CapsLockIndicatorFeatureFlag.isHidden(plistData: data))
    }

    func testNonDictionaryFlagValueMeansIndicatorIsShown() throws {
        let data = try plistData([
            "redesigned_text_cursor": false
        ])

        XCTAssertFalse(CapsLockIndicatorFeatureFlag.isHidden(plistData: data))
    }
}

final class CapsLockIndicatorRestartPolicyTests: XCTestCase {
    private let bootTime: TimeInterval = 1_700_000_000

    func testFirstObservationRecordsSnapshotWithoutPendingRestart() {
        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: nil,
            currentBootTime: bootTime,
            currentHidden: true
        )

        XCTAssertEqual(
            result.snapshot,
            CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: true)
        )
        XCTAssertFalse(result.restartPending)
    }

    func testUnchangedStateWithinSameBootIsNotPending() {
        let snapshot = CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: false)

        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: snapshot,
            currentBootTime: bootTime,
            currentHidden: false
        )

        XCTAssertEqual(result.snapshot, snapshot)
        XCTAssertFalse(result.restartPending)
    }

    func testChangedStateWithinSameBootIsPending() {
        let snapshot = CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: false)

        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: snapshot,
            currentBootTime: bootTime,
            currentHidden: true
        )

        XCTAssertEqual(result.snapshot, snapshot)
        XCTAssertTrue(result.restartPending)
    }

    func testTogglingBackWithinSameBootClearsPendingRestart() {
        let snapshot = CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: false)

        let changed = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: snapshot,
            currentBootTime: bootTime,
            currentHidden: true
        )
        let restored = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: changed.snapshot,
            currentBootTime: bootTime,
            currentHidden: false
        )

        XCTAssertTrue(changed.restartPending)
        XCTAssertFalse(restored.restartPending)
    }

    func testRebootRefreshesSnapshotAndClearsPendingRestart() {
        let snapshot = CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: false)
        let laterBootTime = bootTime + 3_600

        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: snapshot,
            currentBootTime: laterBootTime,
            currentHidden: true
        )

        XCTAssertEqual(
            result.snapshot,
            CapsLockIndicatorBootSnapshot(bootTime: laterBootTime, hiddenAtBoot: true)
        )
        XCTAssertFalse(result.restartPending)
    }

    func testSmallBootTimeDriftIsTreatedAsTheSameBoot() {
        // kern.boottime can shift by a few seconds when the clock is
        // adjusted, so nearby readings must not look like a reboot.
        let snapshot = CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: false)

        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: snapshot,
            currentBootTime: bootTime + 5,
            currentHidden: true
        )

        XCTAssertEqual(result.snapshot, snapshot)
        XCTAssertTrue(result.restartPending)
    }

    func testUnavailableBootTimeKeepsSnapshotAndComparesState() {
        let snapshot = CapsLockIndicatorBootSnapshot(bootTime: bootTime, hiddenAtBoot: false)

        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: snapshot,
            currentBootTime: nil,
            currentHidden: true
        )

        XCTAssertEqual(result.snapshot, snapshot)
        XCTAssertTrue(result.restartPending)
    }

    func testUnavailableBootTimeWithoutSnapshotIsNotPending() {
        let result = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: nil,
            currentBootTime: nil,
            currentHidden: true
        )

        XCTAssertNil(result.snapshot)
        XCTAssertFalse(result.restartPending)
    }
}

final class SystemBootTimeReaderTests: XCTestCase {
    func testReadsAPlausibleBootTime() throws {
        let bootTime = try XCTUnwrap(SystemBootTimeReader.bootTime())

        XCTAssertGreaterThan(bootTime, 0)
        XCTAssertLessThanOrEqual(bootTime, Date().timeIntervalSince1970)
    }
}
