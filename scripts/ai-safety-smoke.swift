import Darwin
import Foundation

enum SmokeFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): message
        }
    }
}

@main
struct AISafetySmoke {
    static func main() throws {
        try stateMachineChecks()
        try storeBarrierChecks()
        try configurationChecks()
        print("ai-safety-smoke: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw SmokeFailure.failed(message) }
    }

    private static func stateMachineChecks() throws {
        let start = Date(timeIntervalSince1970: 10_000)
        var state = AIActivityState.failSafe
        state.record(event(.userPromptSubmit, turn: "old"), at: start)
        state.record(event(.userPromptSubmit, turn: "new"), at: start.addingTimeInterval(3))
        state.record(event(.stop, turn: "old"), at: start.addingTimeInterval(4))
        try expect(
            state.decision(at: start.addingTimeInterval(10_000), quietPeriod: 300) == .running,
            "late Codex Stop ended a newer turn"
        )

        state.record(event(.permissionRequest, turn: "new"), at: start.addingTimeInterval(5))
        try expect(
            state.decision(at: start.addingTimeInterval(20_000), quietPeriod: 300) == .running,
            "PermissionRequest aged into eligibility"
        )

        var claude = AIActivityState.failSafe
        claude.record(
            AIActivityEvent(source: "claude", kind: .userPromptSubmit, sessionID: "s", turnID: nil, agentID: nil),
            at: start
        )
        claude.record(
            AIActivityEvent(
                source: "claude", kind: .stop, sessionID: "s", turnID: nil,
                agentID: nil, hasBackgroundWork: true
            ),
            at: start.addingTimeInterval(1)
        )
        try expect(
            claude.decision(at: start.addingTimeInterval(20_000), quietPeriod: 300) == .running,
            "Claude background work did not remain active"
        )
        claude.record(
            AIActivityEvent(source: "claude", kind: .stop, sessionID: "s", turnID: nil, agentID: nil),
            at: start.addingTimeInterval(2)
        )
        try expect(
            claude.decision(at: start.addingTimeInterval(20_000), quietPeriod: 300) == .unsafe,
            "turn-less Claude Stop unlocked sleep eligibility"
        )

        let beforeUnknown = state.safetyEpoch
        state.record(event(.stop, session: "unknown", turn: "ghost"), at: start.addingTimeInterval(6))
        try expect(state.safetyEpoch != beforeUnknown, "unknown event did not start a safety epoch")
        try expect(
            state.decision(at: start.addingTimeInterval(20_000), quietPeriod: 300) == .unsafe,
            "unknown event left stale eligibility"
        )
    }

    private static func storeBarrierChecks() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let store = AIActivityStore(
            supportDirectoryURL: home.appendingPathComponent("support"),
            securityRootURL: home
        )
        let start = Date(timeIntervalSince1970: 20_000)
        let first = try unwrap(store.establishSafetyBarrier(at: start), "initial barrier write failed")
        _ = store.record(event(.userPromptSubmit, turn: "t"), at: start.addingTimeInterval(1))
        _ = store.record(event(.stop, turn: "t"), at: start.addingTimeInterval(2))
        let eligible = try unwrap(store.load(), "eligible state missing")
        try expect(eligible.decision(at: start.addingTimeInterval(302), quietPeriod: 300) == .eligible, "fresh cycle not eligible")
        let restarted = try unwrap(store.establishSafetyBarrier(at: start.addingTimeInterval(400)), "restart barrier failed")
        try expect(restarted.safetyEpoch != first.safetyEpoch, "restart reused old safety epoch")
        try expect(restarted.decision(at: start.addingTimeInterval(1_000), quietPeriod: 300) == .unsafe, "restart retained eligibility")

        let badSupport = home.appendingPathComponent("bad-support")
        try FileManager.default.createDirectory(at: badSupport, withIntermediateDirectories: true)
        let stateURL = badSupport.appendingPathComponent(AIActivityStore.stateFilename)
        try expect(symlink("/missing/capsomnia-state", stateURL.path) == 0, "could not create dangling state symlink")
        let failedStore = AIActivityStore(supportDirectoryURL: badSupport, securityRootURL: home)
        try expect(
            failedStore.establishSafetyBarrier() == nil,
            "state store followed dangling symlink"
        )
        try expect(failedStore.loadIfWriteBarrierClear() == nil, "failed write did not leave a safety barrier")
    }

    private static func configurationChecks() throws {
        let nested = "model = \"test\"\n\n[profiles.work]\nnotify = [\"nested\"]\n"
        let installed = try AIIntegrationManager.replacingNotify(
            in: nested,
            with: ["/tmp/capsomnia-ai-hook", "codex"]
        )
        try expect(installed.previous == nil, "nested notify was treated as root notify")
        try expect(installed.text.contains("notify = [\"nested\"]"), "nested notify was overwritten")
        let removed = try AIIntegrationManager.replacingNotify(in: installed.text, with: nil)
        try expect(removed.text == nested, "inserted root notify did not round-trip")

        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaConfigSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let codex = home.appendingPathComponent(".codex")
        let claude = home.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        let configURL = codex.appendingPathComponent("config.toml")
        let original = "model = \"test\"\nnotify = [\"old\"] # exact comment\n"
        try Data(original.utf8).write(to: configURL)
        let manager = AIIntegrationManager(
            homeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        let status = manager.ensureInstalled()
        try expect(status.codexConfigured && status.claudeConfigured, "integration install failed: \(status.errors)")
        try expect(manager.inspectInstalled().errors.isEmpty, "installed integration trust check failed")
        var externalEdit = try String(contentsOf: configURL, encoding: .utf8)
        externalEdit += "# external edit after install\n"
        try Data(externalEdit.utf8).write(to: configURL)
        try expect(manager.ensureInstalled().codexConfigured, "reinstall after external edit failed")
        try expect(manager.removeInstalledIntegrations().isEmpty, "integration uninstall failed")
        let restoredConfig = try String(contentsOf: configURL, encoding: .utf8)
        try expect(
            restoredConfig == original + "# external edit after install\n",
            "Codex external edit was not preserved"
        )
        try expect(!FileManager.default.fileExists(atPath: codex.appendingPathComponent("hooks.json").path), "created Codex hooks file remained")
        try expect(!FileManager.default.fileExists(atPath: claude.appendingPathComponent("settings.json").path), "created Claude settings remained")

        let disabledHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaDisabledHooksSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: disabledHome) }
        let disabledCodex = disabledHome.appendingPathComponent(".codex")
        let disabledClaude = disabledHome.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: disabledCodex, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: disabledClaude, withIntermediateDirectories: true)
        try Data("[features]\nhooks = false\n".utf8).write(to: disabledCodex.appendingPathComponent("config.toml"))
        try JSONSerialization.data(withJSONObject: ["disableAllHooks": true]).write(
            to: disabledClaude.appendingPathComponent("settings.json")
        )
        let disabledManager = AIIntegrationManager(
            homeDirectory: disabledHome,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        )
        let disabledStatus = disabledManager.ensureInstalled()
        try expect(!disabledStatus.codexConfigured, "Codex features.hooks=false was trusted")
        try expect(!disabledStatus.claudeConfigured, "Claude disableAllHooks=true was trusted")

        for config in [
            "[features]\n\"hooks\" = false\n",
            "[\"features\"]\n'codex_hooks' = false\n",
            "\"features\".\"hooks\" = false\n",
            "features = { hooks = false }\n"
        ] {
            let equivalentHome = FileManager.default.temporaryDirectory
                .appendingPathComponent("CapsomniaEquivalentDisable-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: equivalentHome) }
            let equivalentCodex = equivalentHome.appendingPathComponent(".codex")
            try FileManager.default.createDirectory(at: equivalentCodex, withIntermediateDirectories: true)
            try Data(config.utf8).write(to: equivalentCodex.appendingPathComponent("config.toml"))
            let equivalentManager = AIIntegrationManager(
                homeDirectory: equivalentHome,
                bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
            )
            try expect(
                !equivalentManager.ensureInstalled().codexConfigured,
                "equivalent disabled Codex hooks form was trusted"
            )
        }

        let danglingHooks = codex.appendingPathComponent("hooks.json")
        try expect(symlink("/missing/capsomnia-hooks", danglingHooks.path) == 0, "could not create dangling hooks symlink")
        let before = try Data(contentsOf: configURL)
        let rejected = manager.ensureInstalled()
        try expect(!rejected.codexConfigured, "dangling hooks symlink was accepted")
        let after = try Data(contentsOf: configURL)
        try expect(after == before, "failed transaction changed Codex config")

#if DEBUG
        try FileManager.default.removeItem(at: danglingHooks)
        let rollbackManager = AIIntegrationManager(
            testingHomeDirectory: home,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, _ in
            if index == 2 { throw AIIntegrationError.configurationChangedDuringUpdate }
        }
        let rollbackStatus = rollbackManager.ensureInstalled()
        try expect(!rollbackStatus.codexConfigured, "injected transaction failure was ignored")
        let rolledBack = try Data(contentsOf: configURL)
        try expect(rolledBack == before, "later write failure did not roll back Codex config")
        let backupURL = home.appendingPathComponent(
            "Library/Application Support/Capsomnia/codex-notify-backup.json"
        )
        try expect(!FileManager.default.fileExists(atPath: backupURL.path), "failed transaction left backup state")

        let concurrentHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaConcurrentSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: concurrentHome) }
        let concurrentCodex = concurrentHome.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: concurrentCodex, withIntermediateDirectories: true)
        let concurrentConfigURL = concurrentCodex.appendingPathComponent("config.toml")
        let concurrentHooksURL = concurrentCodex.appendingPathComponent("hooks.json")
        let concurrentOriginalConfig = Data("model = \"test\"\n".utf8)
        let concurrentOriginalHooks = try JSONSerialization.data(withJSONObject: ["external": "before"])
        let concurrentEdit = try JSONSerialization.data(withJSONObject: ["external": "during"])
        try concurrentOriginalConfig.write(to: concurrentConfigURL)
        try concurrentOriginalHooks.write(to: concurrentHooksURL)
        let concurrentManager = AIIntegrationManager(
            testingHomeDirectory: concurrentHome,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, url in
            if index == 2 { try concurrentEdit.write(to: url) }
        }
        let concurrentStatus = concurrentManager.ensureInstalled()
        let concurrentRolledBackConfig = try Data(contentsOf: concurrentConfigURL)
        let concurrentPreservedHooks = try Data(contentsOf: concurrentHooksURL)
        try expect(!concurrentStatus.codexConfigured, "concurrent hooks edit was overwritten")
        try expect(concurrentRolledBackConfig == concurrentOriginalConfig, "config rollback failed after concurrent edit")
        try expect(concurrentPreservedHooks == concurrentEdit, "concurrent hooks bytes were not preserved")

        let secondRaceHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("CapsomniaSecondRaceSmoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: secondRaceHome) }
        let secondRaceCodex = secondRaceHome.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: secondRaceCodex, withIntermediateDirectories: true)
        let secondRaceConfigURL = secondRaceCodex.appendingPathComponent("config.toml")
        let secondRaceHooksURL = secondRaceCodex.appendingPathComponent("hooks.json")
        let secondRaceOriginalConfig = Data("model = \"test\"\n".utf8)
        let secondRaceOriginalHooks = try JSONSerialization.data(withJSONObject: ["external": "before"])
        let firstRaceEdit = try JSONSerialization.data(withJSONObject: ["external": "first"])
        let secondRaceEdit = try JSONSerialization.data(withJSONObject: ["external": "second"])
        try secondRaceOriginalConfig.write(to: secondRaceConfigURL)
        try secondRaceOriginalHooks.write(to: secondRaceHooksURL)
        let secondRaceManager = AIIntegrationManager(
            testingHomeDirectory: secondRaceHome,
            bridgeExecutableURL: URL(fileURLWithPath: "/tmp/capsomnia-ai-hook")
        ) { index, url in
            if index == 2 { try firstRaceEdit.write(to: url) }
            if index == -1 { try secondRaceEdit.write(to: url) }
        }
        let secondRaceStatus = secondRaceManager.ensureInstalled()
        let secondRaceFinalConfig = try Data(contentsOf: secondRaceConfigURL)
        let secondRaceFinalHooks = try Data(contentsOf: secondRaceHooksURL)
        try expect(!secondRaceStatus.codexConfigured, "second conflict-window edit was overwritten")
        try expect(secondRaceFinalConfig == secondRaceOriginalConfig, "second-race config rollback failed")
        try expect(secondRaceFinalHooks == secondRaceEdit, "second conflict-window bytes were lost")
#endif
    }

    private static func event(
        _ kind: AIActivityEventKind,
        session: String = "s",
        turn: String
    ) -> AIActivityEvent {
        AIActivityEvent(source: "codex", kind: kind, sessionID: session, turnID: turn, agentID: nil)
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw SmokeFailure.failed(message) }
        return value
    }
}
