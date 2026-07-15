import Foundation
import Darwin
import XCTest
@testable import Capsomnia
@testable import CapsomniaIntegrationKit

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

    func testCodexNotifyOnlyReadsAndWritesRootKey() throws {
        let config = """
        model = "gpt-test"

        [profiles.work]
        notify = ["/nested/notifier", "keep-me"]
        """
        let installed = try AIIntegrationManager.replacingNotify(
            in: config,
            with: ["/tmp/capsomnia-ai-hook", "codex"]
        )
        XCTAssertNil(installed.previous)
        XCTAssertTrue(installed.text.hasPrefix("notify = [\"/tmp/capsomnia-ai-hook\", \"codex\"]"))
        XCTAssertTrue(installed.text.contains("notify = [\"/nested/notifier\", \"keep-me\"]"))
        XCTAssertEqual(try AIIntegrationManager.replacingNotify(in: installed.text, with: nil).text, config)
    }

    func testCodexNotifyRejectsMalformedTableSyntax() {
        let config = "model = \"gpt-test\"\n[features\nnotify = [\"nested\"]\n"
        XCTAssertThrowsError(
            try AIIntegrationManager.replacingNotify(in: config, with: ["/tmp/hook", "codex"])
        )
    }

    func testCodexIntegrationRoundTripRestoresOriginalNotifier() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let original = "model = \"gpt-test\"\nnotify = [\"python3\", \"/tmp/notify.py\"] # preserve this\n"
        try original.write(to: configURL, atomically: true, encoding: .utf8)
        let unrelatedHook: [String: Any] = [
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "/tmp/unrelated"]]]]]
        ]
        try JSONSerialization.data(withJSONObject: unrelatedHook).write(to: hooksURL)

        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/Applications/Capsomnia.app/Contents/Resources/capsomnia-ai-hook")
        )
        let installed = manager.ensureInstalled()
        XCTAssertTrue(installed.codexConfigured)
        XCTAssertTrue(try String(contentsOf: configURL, encoding: .utf8).contains("capsomnia-ai-hook"))
        XCTAssertTrue(try String(contentsOf: hooksURL, encoding: .utf8).contains("codex-hook"))
        XCTAssertTrue(manager.removeInstalledIntegrations().isEmpty)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
        let restoredHooks = try String(contentsOf: hooksURL, encoding: .utf8)
        XCTAssertTrue(restoredHooks.contains("unrelated"))
        XCTAssertFalse(restoredHooks.contains("codex-hook"))
    }

    func testIntegrationRejectsDanglingSymlinkWithoutChangingConfig() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let original = "model = \"gpt-test\"\n"
        try original.write(to: configURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(symlink("/definitely/missing/capsomnia-hooks", hooksURL.path), 0)

        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.codexConfigured)
        XCTAssertFalse(status.errors.isEmpty)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
    }

    func testCreatedIntegrationFilesAreRemovedOnUninstall() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude"),
            withIntermediateDirectories: true
        )
        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        let installed = manager.ensureInstalled()
        XCTAssertTrue(installed.codexConfigured)
        XCTAssertTrue(installed.claudeConfigured)
        XCTAssertTrue(manager.removeInstalledIntegrations().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".codex/config.toml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".codex/hooks.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".claude/settings.json").path))
    }

    func testCodexInstallRollsBackConfigWhenLaterTransactionWriteFails() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let original = "model = \"gpt-test\"\n"
        try Data(original.utf8).write(to: configURL)
        let manager = AIIntegrationManager(
            testingHomeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, _ in
            if index == 2 { throw AIIntegrationError.configurationChangedDuringUpdate }
        }
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.codexConfigured)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: home.appendingPathComponent("Library/Application Support/Capsomnia/codex-notify-backup.json").path
        ))
    }

    func testCodexConcurrentHooksEditIsPreservedAndTransactionRollsBack() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let originalConfig = Data("model = \"gpt-test\"\n".utf8)
        let originalHooks = try JSONSerialization.data(withJSONObject: ["external": "before"])
        let concurrentHooks = try JSONSerialization.data(withJSONObject: ["external": "during"])
        try originalConfig.write(to: configURL)
        try originalHooks.write(to: hooksURL)

        let manager = AIIntegrationManager(
            testingHomeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, url in
            if index == 2 { try concurrentHooks.write(to: url) }
        }
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.codexConfigured)
        XCTAssertEqual(try Data(contentsOf: configURL), originalConfig)
        XCTAssertEqual(try Data(contentsOf: hooksURL), concurrentHooks)
    }

    func testSecondConcurrentHooksEditDuringConflictRecoveryIsNotLost() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let originalConfig = Data("model = \"gpt-test\"\n".utf8)
        let originalHooks = try JSONSerialization.data(withJSONObject: ["external": "before"])
        let firstEdit = try JSONSerialization.data(withJSONObject: ["external": "first"])
        let secondEdit = try JSONSerialization.data(withJSONObject: ["external": "second"])
        try originalConfig.write(to: configURL)
        try originalHooks.write(to: hooksURL)

        let manager = AIIntegrationManager(
            testingHomeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, url in
            if index == 2 { try firstEdit.write(to: url) }
            if index == -1 { try secondEdit.write(to: url) }
        }
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.codexConfigured)
        XCTAssertEqual(try Data(contentsOf: configURL), originalConfig)
        XCTAssertEqual(try Data(contentsOf: hooksURL), secondEdit)
        let recoveryFiles = try FileManager.default.contentsOfDirectory(atPath: codexDirectory.path)
            .filter { $0.hasPrefix(".capsomnia-swap-") }
        XCTAssertFalse(recoveryFiles.isEmpty)
    }

    func testClaudeConcurrentSettingsEditIsPreservedAndTransactionRollsBack() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let claudeDirectory = home.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        let settingsURL = claudeDirectory.appendingPathComponent("settings.json")
        let original = try JSONSerialization.data(withJSONObject: ["external": "before"])
        let concurrent = try JSONSerialization.data(withJSONObject: ["external": "during"])
        try original.write(to: settingsURL)

        let manager = AIIntegrationManager(
            testingHomeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, url in
            if index == 1 { try concurrent.write(to: url) }
        }
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.claudeConfigured)
        XCTAssertEqual(try Data(contentsOf: settingsURL), concurrent)
    }

    func testExplicitHookDisableFlagsAreNeverTrusted() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        let claudeDirectory = home.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try Data("[features]\nhooks = false\n".utf8).write(
            to: codexDirectory.appendingPathComponent("config.toml")
        )
        try JSONSerialization.data(withJSONObject: ["disableAllHooks": true]).write(
            to: claudeDirectory.appendingPathComponent("settings.json")
        )
        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        let status = manager.ensureInstalled()
        XCTAssertFalse(status.codexConfigured)
        XCTAssertFalse(status.claudeConfigured)
    }

    func testEquivalentCodexHookDisableFormsAreNeverTrusted() throws {
        let forms = [
            "[features]\n\"hooks\" = false\n",
            "[\"features\"]\n'codex_hooks' = false\n",
            "\"features\".\"hooks\" = false\n",
            "features = { hooks = false }\n"
        ]
        for config in forms {
            let home = try makeTemporaryHome()
            defer { try? FileManager.default.removeItem(at: home) }
            let directory = home.appendingPathComponent(".codex")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(config.utf8).write(to: directory.appendingPathComponent("config.toml"))
            let manager = AIIntegrationManager(
                homeDirectory: home,
                bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
            )
            XCTAssertFalse(manager.ensureInstalled().codexConfigured, "trusted disabled form: \(config)")
        }
    }

    func testAlteredOwnedHookShapeIsNotTrusted() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        XCTAssertTrue(manager.ensureInstalled().codexConfigured)
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        var root = try JSONSerialization.jsonObject(with: Data(contentsOf: hooksURL)) as? [String: Any] ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var groups = hooks["Stop"] as? [[String: Any]] ?? []
        var handlers = groups[0]["hooks"] as? [[String: Any]] ?? []
        handlers[0]["async"] = true
        groups[0]["hooks"] = handlers
        hooks["Stop"] = groups
        root["hooks"] = hooks
        try JSONSerialization.data(withJSONObject: root).write(to: hooksURL)
        XCTAssertFalse(manager.inspectInstalled().codexConfigured)
    }

    func testUninstallPreservesExternalConfigEditWhileRestoringNotify() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let original = "notify = [\"old\"] # original tail\nmodel = \"test\"\n"
        try Data(original.utf8).write(to: configURL)
        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        XCTAssertTrue(manager.ensureInstalled().codexConfigured)
        var externallyEdited = try String(contentsOf: configURL, encoding: .utf8)
        externallyEdited += "# external concurrent edit\n"
        try Data(externallyEdited.utf8).write(to: configURL)
        XCTAssertTrue(manager.ensureInstalled().codexConfigured)
        XCTAssertTrue(manager.removeInstalledIntegrations().isEmpty)
        let restored = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(restored.contains("notify = [\"old\"] # original tail"))
        XCTAssertTrue(restored.contains("# external concurrent edit"))
        XCTAssertFalse(restored.contains("capsomnia-ai-hook"))
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
        var externallyEdited = try JSONSerialization.jsonObject(
            with: Data(contentsOf: settingsURL)
        ) as? [String: Any] ?? [:]
        externallyEdited["external_after_install"] = true
        try JSONSerialization.data(withJSONObject: externallyEdited).write(to: settingsURL)
        XCTAssertTrue(manager.ensureInstalled().claudeConfigured)
        XCTAssertTrue(manager.removeInstalledIntegrations().isEmpty)
        let data = try Data(contentsOf: settingsURL)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("check-capsomnia-ai-hook-health"))
        XCTAssertTrue(text.contains("external_after_install"))
        XCTAssertFalse(text.contains("capsomnia-ai-hook' claude"))
        XCTAssertFalse(text.contains("claude-hook"))
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

    func testActivityStateNeedsACompleteFreshCycleBeforeSleep() {
        let start = Date(timeIntervalSince1970: 1_000)
        let prompt = AIActivityEvent(
            source: "codex", kind: .userPromptSubmit, sessionID: "s1", turnID: "t1", agentID: nil
        )
        var state = AIActivityState.failSafe
        XCTAssertEqual(state.decision(at: start, quietPeriod: 300), .unsafe)
        state.record(prompt, at: start)
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(1), quietPeriod: 300), .running)

        state.record(
            AIActivityEvent(source: "codex", kind: .stop, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start.addingTimeInterval(10)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(309), quietPeriod: 300), .waiting)
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(310), quietPeriod: 300), .eligible)
    }

    func testRunningActivityNeverAgesIntoSleepEligibility() {
        let start = Date(timeIntervalSince1970: 1_500)
        let state = AIActivityState(
            requiresFreshCycle: false,
            lastProgressAt: start,
            activeSessions: [
                "codex:s1": AITrackedActivity(phase: .running, updatedAt: start)
            ]
        )
        XCTAssertEqual(
            state.decision(at: start.addingTimeInterval(86_400), quietPeriod: 300),
            .running
        )
    }

    func testPermissionRequestNeverAgesIntoSleepEligibility() {
        let start = Date(timeIntervalSince1970: 1_700)
        var state = AIActivityState.failSafe
        state.record(
            AIActivityEvent(source: "codex", kind: .userPromptSubmit, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start
        )
        state.record(
            AIActivityEvent(source: "codex", kind: .permissionRequest, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start.addingTimeInterval(1)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(86_400), quietPeriod: 300), .running)
    }

    func testLateCodexStopCannotEndNewTurn() {
        let start = Date(timeIntervalSince1970: 1_800)
        var state = AIActivityState.failSafe
        state.record(
            AIActivityEvent(source: "codex", kind: .userPromptSubmit, sessionID: "s1", turnID: "old", agentID: nil),
            at: start
        )
        state.record(
            AIActivityEvent(source: "codex", kind: .userPromptSubmit, sessionID: "s1", turnID: "new", agentID: nil),
            at: start.addingTimeInterval(1)
        )
        state.record(
            AIActivityEvent(source: "codex", kind: .stop, sessionID: "s1", turnID: "old", agentID: nil),
            at: start.addingTimeInterval(2)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(10_000), quietPeriod: 300), .running)
    }

    func testActivityStateKeepsParallelSubagentRunning() {
        let start = Date(timeIntervalSince1970: 2_000)
        var state = AIActivityState.failSafe
        state.record(
            AIActivityEvent(source: "claude", kind: .userPromptSubmit, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start
        )
        state.record(
            AIActivityEvent(source: "claude", kind: .subagentStart, sessionID: "s1", turnID: "t1", agentID: "a1"),
            at: start.addingTimeInterval(1)
        )
        state.record(
            AIActivityEvent(source: "claude", kind: .stop, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start.addingTimeInterval(2)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(100), quietPeriod: 300), .running)
        state.record(
            AIActivityEvent(source: "claude", kind: .subagentStop, sessionID: "s1", turnID: "t1", agentID: "a1"),
            at: start.addingTimeInterval(101)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(400), quietPeriod: 300), .waiting)
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(401), quietPeriod: 300), .eligible)
    }

    func testUnknownProgressEventMakesActivityStateFailSafe() {
        var state = AIActivityState.failSafe
        let now = Date(timeIntervalSince1970: 3_000)
        state.record(
            AIActivityEvent(source: "codex", kind: .postToolUse, sessionID: "unknown", turnID: "t", agentID: nil),
            at: now
        )
        XCTAssertEqual(state.decision(at: now.addingTimeInterval(600), quietPeriod: 300), .unsafe)
    }

    func testUnknownEventStartsNewEpochAndOldStopCannotUnlockIt() {
        let start = Date(timeIntervalSince1970: 3_500)
        var state = AIActivityState.failSafe
        state.record(
            AIActivityEvent(source: "codex", kind: .userPromptSubmit, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start
        )
        let firstEpoch = state.safetyEpoch
        state.record(
            AIActivityEvent(source: "codex", kind: .stop, sessionID: "unknown", turnID: "old", agentID: nil),
            at: start.addingTimeInterval(1)
        )
        XCTAssertNotEqual(state.safetyEpoch, firstEpoch)
        let safeEpoch = state.safetyEpoch
        state.record(
            AIActivityEvent(source: "codex", kind: .stop, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start.addingTimeInterval(2)
        )
        XCTAssertNotEqual(state.safetyEpoch, safeEpoch)
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(1_000), quietPeriod: 300), .unsafe)
    }

    func testClaudeBackgroundTasksRemainRunningAndTurnlessStopFailsClosed() {
        let start = Date(timeIntervalSince1970: 4_000)
        var state = AIActivityState.failSafe
        state.record(
            AIActivityEvent(source: "claude", kind: .userPromptSubmit, sessionID: "s1", turnID: nil, agentID: nil),
            at: start
        )
        state.record(
            AIActivityEvent(
                source: "claude", kind: .stop, sessionID: "s1", turnID: nil,
                agentID: nil, hasBackgroundWork: true
            ),
            at: start.addingTimeInterval(10)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(10_000), quietPeriod: 300), .running)
        state.record(
            AIActivityEvent(source: "claude", kind: .stop, sessionID: "s1", turnID: nil, agentID: nil),
            at: start.addingTimeInterval(20)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(320), quietPeriod: 300), .unsafe)
    }

    func testOverlappingClaudePromptsFailClosedWithoutTurnID() {
        let start = Date(timeIntervalSince1970: 4_500)
        var state = AIActivityState.failSafe
        for offset in [0.0, 1.0] {
            state.record(
                AIActivityEvent(source: "claude", kind: .userPromptSubmit, sessionID: "s1", turnID: nil, agentID: nil),
                at: start.addingTimeInterval(offset)
            )
        }
        state.record(
            AIActivityEvent(source: "claude", kind: .stop, sessionID: "s1", turnID: nil, agentID: nil),
            at: start.addingTimeInterval(2)
        )
        XCTAssertEqual(state.decision(at: start.addingTimeInterval(1_000), quietPeriod: 300), .unsafe)
    }

    func testRestartBarrierInvalidatesPreviouslyEligibleState() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let support = home.appendingPathComponent("support")
        let store = AIActivityStore(supportDirectoryURL: support, securityRootURL: home)
        let start = Date(timeIntervalSince1970: 5_000)
        let initial = try XCTUnwrap(store.establishSafetyBarrier(at: start))
        _ = store.record(
            AIActivityEvent(source: "codex", kind: .userPromptSubmit, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start.addingTimeInterval(1)
        )
        _ = store.record(
            AIActivityEvent(source: "codex", kind: .stop, sessionID: "s1", turnID: "t1", agentID: nil),
            at: start.addingTimeInterval(2)
        )
        XCTAssertEqual(store.load()?.decision(at: start.addingTimeInterval(302), quietPeriod: 300), .eligible)
        let restarted = try XCTUnwrap(store.establishSafetyBarrier(at: start.addingTimeInterval(400)))
        XCTAssertNotEqual(restarted.safetyEpoch, initial.safetyEpoch)
        XCTAssertEqual(restarted.decision(at: start.addingTimeInterval(1_000), quietPeriod: 300), .unsafe)
    }

    func testStateWriteFailureCannotEstablishTrustedBarrier() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let support = home.appendingPathComponent("support")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let stateURL = support.appendingPathComponent(AIActivityStore.stateFilename)
        XCTAssertEqual(symlink("/definitely/missing/capsomnia-state", stateURL.path), 0)
        let store = AIActivityStore(supportDirectoryURL: support, securityRootURL: home)
        XCTAssertNil(store.establishSafetyBarrier())
        XCTAssertNil(store.loadIfWriteBarrierClear())
    }

    func testActivityPayloadOnlyAcceptsLifecycleIdentifiers() {
        let payload = #"{"hook_event_name":"SubagentStart","session_id":"session","turn_id":"turn","agent_id":"agent","prompt":"do not retain"}"#
        let event = AIActivityPayload.event(source: "codex", payload: payload)
        XCTAssertEqual(event?.sessionID, "session")
        XCTAssertEqual(event?.agentID, "agent")
        XCTAssertNil(AIActivityPayload.event(source: "codex", payload: #"{"hook_event_name":"Stop"}"#))
    }

    func testBatteryProtectionRequiresBatteryPowerAtOrBelowTenPercent() {
        XCTAssertTrue(BatteryProtectionPolicy.shouldForceSleep(PowerSourceStatus(isACPower: false, percent: 10)))
        XCTAssertFalse(BatteryProtectionPolicy.shouldForceSleep(PowerSourceStatus(isACPower: true, percent: 1)))
        XCTAssertFalse(BatteryProtectionPolicy.shouldForceSleep(PowerSourceStatus(isACPower: false, percent: 11)))
        XCTAssertEqual(
            PowerSourceReader.parse("Now drawing from 'Battery Power'\n -InternalBattery-0 9%; discharging;"),
            PowerSourceStatus(isACPower: false, percent: 9)
        )
        XCTAssertEqual(
            PowerSourceReader.parse("Now drawing from 'AC Power'\n -InternalBattery-0 2%; charging;"),
            PowerSourceStatus(isACPower: true, percent: 2)
        )
        XCTAssertNil(PowerSourceReader.parse("Battery Power 9%"))
    }

    func testAutomaticSleepPhysicalPreflightFailsClosedAcrossTOCTOUChanges() {
        let lowBattery = PowerSourceStatus(isACPower: false, percent: 9)
        XCTAssertTrue(AutomaticSleepPhysicalPreflight.allowsSleep(
            masterEnabled: true, lidClosed: true, requiresLowBattery: true, powerStatus: lowBattery
        ))
        XCTAssertFalse(AutomaticSleepPhysicalPreflight.allowsSleep(
            masterEnabled: true, lidClosed: false, requiresLowBattery: true, powerStatus: lowBattery
        ))
        XCTAssertFalse(AutomaticSleepPhysicalPreflight.allowsSleep(
            masterEnabled: true, lidClosed: true, requiresLowBattery: true,
            powerStatus: PowerSourceStatus(isACPower: true, percent: 9)
        ))
        XCTAssertFalse(AutomaticSleepPhysicalPreflight.allowsSleep(
            masterEnabled: true, lidClosed: true, requiresLowBattery: true, powerStatus: nil
        ))
    }

    private func makeTemporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
