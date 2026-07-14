import Foundation
import XCTest
@testable import Capsomnia
import CapsomniaIntegrationKit

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

    func testLaunchAgentDisabledStateParsing() {
        let output = """
        disabled services = {
            "com.github.fuji-mak.capsomnia" => disabled
        }
        """

        XCTAssertFalse(LaunchAgentManager.parseIsEnabled(
            output,
            label: "com.github.fuji-mak.capsomnia"
        ))
    }

    func testLaunchAgentEnabledStateParsing() {
        let output = """
        disabled services = {
            "com.github.fuji-mak.capsomnia" => enabled
        }
        """

        XCTAssertTrue(LaunchAgentManager.parseIsEnabled(
            output,
            label: "com.github.fuji-mak.capsomnia"
        ))
    }

    func testLaunchAgentDefaultsToEnabledWhenNotListed() {
        XCTAssertTrue(LaunchAgentManager.parseIsEnabled(
            "disabled services = {}",
            label: "com.github.fuji-mak.capsomnia"
        ))
    }

    func testCodexNotifyReplacementPreservesPreviousCommand() throws {
        let config = """
        model = "gpt-test"
        notify = ["/existing/notifier", "turn-ended"]

        [features]
        hooks = true
        """

        let result = try AIIntegrationManager.replacingNotify(
            in: config,
            with: ["/Applications/Capsomnia.app/Contents/Resources/capsomnia-ai-hook", "codex"]
        )

        XCTAssertEqual(result.previous, ["/existing/notifier", "turn-ended"])
        XCTAssertTrue(result.text.contains("capsomnia-ai-hook\", \"codex"))
        XCTAssertTrue(result.text.contains("[features]"))
    }

    func testCodexNotifyInsertionAndRemoval() throws {
        let config = "model = \"gpt-test\"\n"
        let installed = try AIIntegrationManager.replacingNotify(
            in: config,
            with: ["/tmp/capsomnia-ai-hook", "codex"]
        )
        XCTAssertNil(installed.previous)
        XCTAssertTrue(installed.text.hasPrefix("notify = "))

        let removed = try AIIntegrationManager.replacingNotify(in: installed.text, with: nil)
        XCTAssertEqual(removed.text, config)
    }

    func testCodexNotifyRejectsMultilineArrayInsteadOfOverwritingIt() {
        let config = """
        notify = [
          "/existing/notifier",
          "turn-ended",
        ]
        """

        XCTAssertThrowsError(
            try AIIntegrationManager.replacingNotify(
                in: config,
                with: ["/tmp/capsomnia-ai-hook", "codex"]
            )
        )
    }

    func testCodexIntegrationRoundTripRestoresOriginalNotifier() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let original = "model = \"gpt-test\"\nnotify = [\"python3\", \"/tmp/notify.py\"]\n"
        try original.write(to: configURL, atomically: true, encoding: .utf8)

        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/Applications/Capsomnia.app/Contents/Resources/capsomnia-ai-hook")
        )
        let installed = manager.ensureInstalled()
        XCTAssertTrue(installed.codexConfigured)
        XCTAssertTrue(try String(contentsOf: configURL).contains("capsomnia-ai-hook"))
        XCTAssertTrue(manager.removeInstalledIntegrations().isEmpty)
        XCTAssertEqual(try String(contentsOf: configURL), original)
    }

    func testUnreadableOrInvalidCodexConfigIsNeverReplaced() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD])
        try invalidUTF8.write(to: configURL)

        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.codexConfigured)
        XCTAssertFalse(status.errors.isEmpty)
        XCTAssertEqual(try Data(contentsOf: configURL), invalidUTF8)
    }

    func testClaudeIntegrationOnlyRemovesItsExactCommand() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let claudeDirectory = home.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        let settingsURL = claudeDirectory.appendingPathComponent("settings.json")
        let unrelated = "/usr/local/bin/check-capsomnia-ai-hook-health"
        let initial: [String: Any] = [
            "hooks": [
                "Stop": [[
                    "hooks": [["type": "command", "command": unrelated]]
                ]]
            ]
        ]
        try JSONSerialization.data(withJSONObject: initial).write(to: settingsURL)

        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/Applications/Capsomnia.app/Contents/Resources/capsomnia-ai-hook")
        )
        XCTAssertTrue(manager.ensureInstalled().claudeConfigured)
        XCTAssertTrue(manager.removeInstalledIntegrations().isEmpty)
        let data = try Data(contentsOf: settingsURL)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains(unrelated))
        XCTAssertFalse(text.contains("capsomnia-ai-hook' claude"))
    }

    func testClaudeTurnsInOneSessionReceiveDistinctEventIDs() {
        let payload = #"{"session_id":"same-session","hook_event_name":"Stop"}"#
        XCTAssertNotEqual(
            AICompletionPayload.eventIdentifier(source: "claude", payload: payload),
            AICompletionPayload.eventIdentifier(source: "claude", payload: payload)
        )
    }

    func testClaudeBackgroundWorkSuppressesCompletion() {
        let payload = #"{"session_id":"s1","background_tasks":[{"id":"task-1"}]}"#
        XCTAssertFalse(AICompletionPayload.shouldEmitCompletion(source: "claude", payload: payload))
        XCTAssertTrue(AICompletionPayload.shouldEmitCompletion(
            source: "claude",
            payload: #"{"session_id":"s1","background_tasks":[]}"#
        ))
    }

    private func makeTemporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
