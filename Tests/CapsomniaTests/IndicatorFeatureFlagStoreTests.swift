import Foundation
import XCTest
@testable import CapsomniaPmsetHelper

final class IndicatorFeatureFlagStoreTests: XCTestCase {
    private var rootURL: URL!
    private var featureFlagDirectoryURL: URL!
    private var backupDirectoryURL: URL!
    private var featureFlagURL: URL!
    private var backupURL: URL!
    private var store: IndicatorFeatureFlagStore!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        featureFlagDirectoryURL = rootURL.appendingPathComponent("FeatureFlags", isDirectory: true)
        backupDirectoryURL = rootURL.appendingPathComponent("Backup", isDirectory: true)
        featureFlagURL = featureFlagDirectoryURL.appendingPathComponent("UIKit.plist")
        backupURL = backupDirectoryURL.appendingPathComponent("CapsLockIndicatorBackup.plist")
        store = IndicatorFeatureFlagStore(
            featureFlagDirectoryURL: featureFlagDirectoryURL,
            backupDirectoryURL: backupDirectoryURL
        )
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
    }

    func testHideCreatesOverrideAndBackupWhenPlistIsMissing() throws {
        try store.hide()

        let flags = try readPlist(featureFlagURL)
        let indicator = try XCTUnwrap(flags["redesigned_text_cursor"] as? [String: Any])
        XCTAssertEqual(indicator["Enabled"] as? Bool, false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        let backupMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: backupURL.path)[.posixPermissions]
                as? NSNumber
        )
        XCTAssertEqual(backupMode.intValue & 0o777, 0o600)
    }

    func testHidePreservesUnrelatedValuesAndOnlyCapturesFirstState() throws {
        try writePlist([
            "other": ["Enabled": true],
            "redesigned_text_cursor": ["Enabled": true, "FutureKey": "keep"]
        ], to: featureFlagURL)

        try store.hide()
        var changed = try readPlist(featureFlagURL)
        var changedIndicator = try XCTUnwrap(
            changed["redesigned_text_cursor"] as? [String: Any]
        )
        changedIndicator["AddedLater"] = "preserve"
        changed["redesigned_text_cursor"] = changedIndicator
        try writePlist(changed, to: featureFlagURL)
        try store.hide()
        try store.show()

        let flags = try readPlist(featureFlagURL)
        XCTAssertEqual((flags["other"] as? [String: Any])?["Enabled"] as? Bool, true)
        let restored = try XCTUnwrap(flags["redesigned_text_cursor"] as? [String: Any])
        XCTAssertEqual(restored["Enabled"] as? Bool, true)
        XCTAssertEqual(restored["FutureKey"] as? String, "keep")
        XCTAssertEqual(restored["AddedLater"] as? String, "preserve")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testRestoreRemovesCapsomniaFileButKeepsFlagsAddedLater() throws {
        try store.hide()
        var flags = try readPlist(featureFlagURL)
        flags["added_later"] = ["Enabled": true]
        try writePlist(flags, to: featureFlagURL)

        try store.restoreIfManaged()

        let restored = try readPlist(featureFlagURL)
        XCTAssertNil(restored["redesigned_text_cursor"])
        XCTAssertEqual((restored["added_later"] as? [String: Any])?["Enabled"] as? Bool, true)
    }

    func testRestoreRemovesPlistCreatedByCapsomnia() throws {
        try store.hide()

        try store.restoreIfManaged()

        XCTAssertFalse(FileManager.default.fileExists(atPath: featureFlagURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testRestoreWithoutBackupDoesNotTouchExistingOverride() throws {
        try writePlist([
            "redesigned_text_cursor": ["Enabled": false]
        ], to: featureFlagURL)
        let original = try Data(contentsOf: featureFlagURL)

        try store.restoreIfManaged()

        XCTAssertEqual(try Data(contentsOf: featureFlagURL), original)
    }

    func testRestoreKeepsPreexistingHiddenOverride() throws {
        try writePlist([
            "redesigned_text_cursor": ["Enabled": false]
        ], to: featureFlagURL)

        try store.hide()
        try store.restoreIfManaged()

        let flags = try readPlist(featureFlagURL)
        let indicator = try XCTUnwrap(flags["redesigned_text_cursor"] as? [String: Any])
        XCTAssertEqual(indicator["Enabled"] as? Bool, false)
    }

    func testMalformedPlistIsNeverReplacedOrDeleted() throws {
        try FileManager.default.createDirectory(
            at: featureFlagDirectoryURL,
            withIntermediateDirectories: true
        )
        let original = Data("not a plist".utf8)
        try original.write(to: featureFlagURL)

        XCTAssertThrowsError(try store.hide())
        XCTAssertEqual(try Data(contentsOf: featureFlagURL), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))

        XCTAssertThrowsError(try store.show())
        XCTAssertEqual(try Data(contentsOf: featureFlagURL), original)
    }

    func testNonDictionaryIndicatorIsNeverOverwritten() throws {
        try writePlist(["redesigned_text_cursor": false], to: featureFlagURL)
        let original = try Data(contentsOf: featureFlagURL)

        XCTAssertThrowsError(try store.hide())
        XCTAssertThrowsError(try store.show())
        XCTAssertEqual(try Data(contentsOf: featureFlagURL), original)
    }

    func testCorruptBackupBlocksFurtherChanges() throws {
        try FileManager.default.createDirectory(
            at: backupDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data("not a plist".utf8).write(to: backupURL)

        XCTAssertThrowsError(try store.hide())
        XCTAssertFalse(FileManager.default.fileExists(atPath: featureFlagURL.path))
        XCTAssertThrowsError(try store.restoreIfManaged())
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    private func writePlist(_ value: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: value,
            format: .xml,
            options: 0
        )
        try data.write(to: url)
    }

    private func readPlist(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }
}
