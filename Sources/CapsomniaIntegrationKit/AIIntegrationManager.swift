import Darwin
import Foundation

public struct AIIntegrationStatus: Equatable {
    public let codexDetected: Bool
    public let codexConfigured: Bool
    public let claudeDetected: Bool
    public let claudeConfigured: Bool
    public let codexHooksConfigured: Bool
    public let claudeHooksConfigured: Bool
    public let errors: [String]

    public init(
        codexDetected: Bool,
        codexConfigured: Bool,
        claudeDetected: Bool,
        claudeConfigured: Bool,
        codexHooksConfigured: Bool = false,
        claudeHooksConfigured: Bool = false,
        errors: [String]
    ) {
        self.codexDetected = codexDetected
        self.codexConfigured = codexConfigured
        self.claudeDetected = claudeDetected
        self.claudeConfigured = claudeConfigured
        self.codexHooksConfigured = codexHooksConfigured
        self.claudeHooksConfigured = claudeHooksConfigured
        self.errors = errors
    }
}

public struct CodexNotifyBackup: Codable, Equatable {
    public let originalNotify: [String]?
    public let originalNotifyLine: String?
    public let originalConfigData: Data?
    public let installedConfigData: Data?
    public let originalHooksData: Data?
    public let installedHooksData: Data?
    public let configExisted: Bool?
    public let hooksExisted: Bool?

    public init(
        originalNotify: [String]?,
        originalNotifyLine: String? = nil,
        originalConfigData: Data? = nil,
        installedConfigData: Data? = nil,
        originalHooksData: Data? = nil,
        installedHooksData: Data? = nil,
        configExisted: Bool? = nil,
        hooksExisted: Bool? = nil
    ) {
        self.originalNotify = originalNotify
        self.originalNotifyLine = originalNotifyLine
        self.originalConfigData = originalConfigData
        self.installedConfigData = installedConfigData
        self.originalHooksData = originalHooksData
        self.installedHooksData = installedHooksData
        self.configExisted = configExisted
        self.hooksExisted = hooksExisted
    }
}

private struct IntegrationFileBackup: Codable, Equatable {
    let originalData: Data?
    let installedData: Data
    let existed: Bool
}

public enum AICompletionPayload {
    public static func shouldEmitCompletion(source: String, payload: String) -> Bool {
        guard source == "claude" else { return true }
        guard let hasBackgroundWork = AIActivityPayload.hasClaudeBackgroundWork(payload: payload) else {
            return false
        }
        return !hasBackgroundWork
    }

    public static func eventIdentifier(source: String, payload: String) -> String {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "\(source):\(UUID().uuidString)"
        }
        let session = object["session_id"] as? String ?? object["session-id"] as? String
        for key in ["prompt_id", "prompt-id", "turn-id", "turn_id"] {
            if let value = object[key] as? String, !value.isEmpty {
                return [source, session, value].compactMap { $0 }.joined(separator: ":")
            }
        }
        return "\(source):\(session ?? "unknown"):\(UUID().uuidString)"
    }
}

public struct AIIntegrationManager {
    public static let appLabel = "com.github.fuji-mak.capsomnia"
    public static let completionNotificationName = "com.github.fuji-mak.capsomnia.aiTaskFinished"
    public static let activityNotificationName = "com.github.fuji-mak.capsomnia.aiActivityChanged"
    public static let bridgeExecutableName = "capsomnia-ai-hook"

    private let homeDirectory: URL
    private let bridgeExecutableURL: URL
    private let fileManager: FileManager
#if DEBUG
    private let transactionWriteObserver: ((Int, URL) throws -> Void)?
#endif

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        bridgeExecutableURL: URL,
        fileManager: FileManager = .default
    ) {
        self.homeDirectory = homeDirectory
        self.bridgeExecutableURL = bridgeExecutableURL
        self.fileManager = fileManager
#if DEBUG
        transactionWriteObserver = nil
#endif
    }

#if DEBUG
    init(
        testingHomeDirectory: URL,
        bridgeExecutableURL: URL,
        fileManager: FileManager = .default,
        transactionWriteObserver: @escaping (Int, URL) throws -> Void
    ) {
        homeDirectory = testingHomeDirectory
        self.bridgeExecutableURL = bridgeExecutableURL
        self.fileManager = fileManager
        self.transactionWriteObserver = transactionWriteObserver
    }
#endif

    public static func bridgeURL(in appBundleURL: URL) -> URL {
        appBundleURL
            .appendingPathComponent("Contents/Resources", isDirectory: true)
            .appendingPathComponent(bridgeExecutableName)
    }

    public var supportDirectoryURL: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/Capsomnia", isDirectory: true)
    }

    public var codexNotifyBackupURL: URL {
        supportDirectoryURL.appendingPathComponent("codex-notify-backup.json")
    }

    private var claudeBackupURL: URL {
        supportDirectoryURL.appendingPathComponent("claude-hooks-backup.json")
    }

    public var activityStore: AIActivityStore {
        AIActivityStore(
            supportDirectoryURL: supportDirectoryURL,
            securityRootURL: homeDirectory,
            fileManager: fileManager
        )
    }

    public func ensureInstalled() -> AIIntegrationStatus {
        var errors: [String] = []
        let codexDetected = isCodexDetected()
        let claudeDetected = isClaudeDetected()
        var codexConfigured = false
        var claudeConfigured = false

        do {
            try prepareSupportDirectory()
        } catch {
            errors.append("support: \(error.localizedDescription)")
            return AIIntegrationStatus(
                codexDetected: codexDetected,
                codexConfigured: false,
                claudeDetected: claudeDetected,
                claudeConfigured: false,
                errors: errors
            )
        }

        if codexDetected {
            do { codexConfigured = try ensureCodexIntegration() }
            catch { errors.append("codex: \(error.localizedDescription)") }
        }
        if claudeDetected {
            do { claudeConfigured = try ensureClaudeIntegration() }
            catch { errors.append("claude: \(error.localizedDescription)") }
        }

        return AIIntegrationStatus(
            codexDetected: codexDetected,
            codexConfigured: codexConfigured,
            claudeDetected: claudeDetected,
            claudeConfigured: claudeConfigured,
            codexHooksConfigured: codexConfigured,
            claudeHooksConfigured: claudeConfigured,
            errors: errors
        )
    }

    // Read-only trust check used immediately before sleep. A stale successful
    // installation result is not enough after an external configuration edit.
    public func inspectInstalled() -> AIIntegrationStatus {
        var errors: [String] = []
        let codexDetected = isCodexDetected()
        let claudeDetected = isClaudeDetected()
        var codexConfigured = false
        var claudeConfigured = false
        if codexDetected {
            do { codexConfigured = try inspectCodexIntegration() }
            catch { errors.append("codex: \(error.localizedDescription)") }
        }
        if claudeDetected {
            do { claudeConfigured = try inspectClaudeIntegration() }
            catch { errors.append("claude: \(error.localizedDescription)") }
        }
        return AIIntegrationStatus(
            codexDetected: codexDetected,
            codexConfigured: codexConfigured,
            claudeDetected: claudeDetected,
            claudeConfigured: claudeConfigured,
            codexHooksConfigured: codexConfigured,
            claudeHooksConfigured: claudeConfigured,
            errors: errors
        )
    }

    public func removeInstalledIntegrations() -> [String] {
        var errors: [String] = []
        do { try removeCodexIntegration() }
        catch { errors.append("codex: \(error.localizedDescription)") }
        do { try removeClaudeIntegration() }
        catch { errors.append("claude: \(error.localizedDescription)") }
        return errors
    }

    public func forwardedCodexNotifyCommand() -> [String]? {
        guard let backup = try? loadCodexBackup(),
              let command = backup.originalNotify,
              !command.isEmpty,
              !isCapsomniaNotify(command) else {
            return nil
        }
        return command
    }

    public static func parseNotifyArray(_ value: String) -> [String]? {
        guard let data = value.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return nil
        }
        return array
    }

    public static func replacingNotify(
        in config: String,
        with replacement: [String]?
    ) throws -> (text: String, previous: [String]?, changed: Bool) {
        let match = try rootNotifyMatch(in: config)
        let newline = config.contains("\r\n") ? "\r\n" : "\n"
        let replacementLine = replacement.map { "notify = \(tomlArray($0))\(newline)" }

        guard let match else {
            guard let replacementLine else { return (config, nil, false) }
            return (replacementLine + config, nil, true)
        }
        guard let valueRange = Range(match.valueRange, in: config),
              let previous = parseNotifyArray(String(config[valueRange])),
              let lineRange = Range(match.lineRange, in: config) else {
            throw AIIntegrationError.unsupportedCodexNotifyFormat
        }
        guard let replacementLine else {
            var updated = config
            updated.removeSubrange(lineRange)
            return (updated, previous, true)
        }
        if String(config[lineRange]) == replacementLine { return (config, previous, false) }
        var updated = config
        updated.replaceSubrange(lineRange, with: replacementLine)
        return (updated, previous, true)
    }

    private func isCodexDetected() -> Bool {
        let directory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        if (try? pathKind(directory)) != .missing { return true }
        let knownPaths = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            homeDirectory.appendingPathComponent(".local/bin/codex").path,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return knownPaths.contains(where: fileManager.isExecutableFile(atPath:))
    }

    private func isClaudeDetected() -> Bool {
        let directory = homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        if (try? pathKind(directory)) != .missing { return true }
        let knownPaths = [
            homeDirectory.appendingPathComponent(".local/bin/claude").path,
            homeDirectory.appendingPathComponent(".claude/local/claude").path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        return knownPaths.contains(where: fileManager.isExecutableFile(atPath:))
    }

    private func ensureCodexIntegration() throws -> Bool {
        let directory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        try createPrivateDirectory(directory)
        let configURL = directory.appendingPathComponent("config.toml")
        let hooksURL = directory.appendingPathComponent("hooks.json")

        return try withExclusiveConfigurationLock(for: configURL) { coordinatedConfigURL in
            let configSnapshot = try readSnapshot(from: coordinatedConfigURL)
            let configText = try decodeText(configSnapshot.data)
            let hooksSnapshot = try readSnapshot(from: hooksURL)
            let hooksRoot = try decodeJSONObject(hooksSnapshot.data)
            let backupSnapshot = try readSnapshot(from: codexNotifyBackupURL)
            let replacement = [bridgeExecutableURL.path, "codex"]

            let existing = try Self.currentRootNotify(in: configText)
            let oldBackup = try decodeCodexBackup(backupSnapshot.data)
            let result = try Self.replacingNotify(in: configText, with: replacement)
            let installedConfigData = Data(result.text.utf8)
            let installedHooksRoot = try replacingCapsomniaHooks(in: hooksRoot, source: "codex")
            let installedHooksData = try encodeJSONObject(installedHooksRoot)

            let backup: CodexNotifyBackup
            if let existing, isCapsomniaNotify(existing) {
                guard let oldBackup else { throw AIIntegrationError.missingCodexNotifyBackup }
                let reconstructedConfig: Data
                if configSnapshot.data == oldBackup.installedConfigData,
                   let originalConfigData = oldBackup.originalConfigData {
                    reconstructedConfig = originalConfigData
                } else {
                    reconstructedConfig = Data(
                        try Self.restoringRootNotify(in: configText, backup: oldBackup).utf8
                    )
                }
                let cleanedHooksRoot = try removingCapsomniaHooks(in: hooksRoot, source: "codex")
                let cleanedHooksData = cleanedHooksRoot.isEmpty ? nil : try encodeJSONObject(cleanedHooksRoot)
                let reconstructedHooksData: Data?
                let reconstructedHooksExisted: Bool
                if hooksSnapshot.data == oldBackup.installedHooksData,
                   oldBackup.hooksExisted != nil {
                    reconstructedHooksData = oldBackup.originalHooksData
                    reconstructedHooksExisted = oldBackup.hooksExisted == true
                } else {
                    reconstructedHooksData = cleanedHooksData
                    reconstructedHooksExisted = cleanedHooksData != nil
                }
                backup = CodexNotifyBackup(
                    originalNotify: oldBackup.originalNotify,
                    originalNotifyLine: oldBackup.originalNotifyLine,
                    originalConfigData: reconstructedConfig,
                    installedConfigData: installedConfigData,
                    originalHooksData: reconstructedHooksData,
                    installedHooksData: installedHooksData,
                    configExisted: oldBackup.configExisted ?? true,
                    hooksExisted: reconstructedHooksExisted
                )
            } else {
                backup = CodexNotifyBackup(
                    originalNotify: result.previous,
                    originalNotifyLine: try Self.rootNotifyLine(in: configText),
                    originalConfigData: configSnapshot.data,
                    installedConfigData: installedConfigData,
                    originalHooksData: hooksSnapshot.data,
                    installedHooksData: installedHooksData,
                    configExisted: configSnapshot.existed,
                    hooksExisted: hooksSnapshot.existed
                )
            }
            let backupData = try encodeCodexBackup(backup)
            try commit([
                FileChange(url: codexNotifyBackupURL, original: backupSnapshot.data, replacement: backupData),
                FileChange(url: coordinatedConfigURL, original: configSnapshot.data, replacement: installedConfigData),
                FileChange(url: hooksURL, original: hooksSnapshot.data, replacement: installedHooksData)
            ])
            return try inspectCodexIntegration()
        }
    }

    private func removeCodexIntegration() throws {
        let directory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        let configURL = directory.appendingPathComponent("config.toml")
        let hooksURL = directory.appendingPathComponent("hooks.json")
        if try pathKind(directory) == .missing {
            try removeBackupIfPresent(codexNotifyBackupURL)
            return
        }
        try rejectSymbolicLinksInPath(directory)
        try withExclusiveConfigurationLock(for: configURL) { coordinatedConfigURL in
            let configSnapshot = try readSnapshot(from: coordinatedConfigURL)
            let hooksSnapshot = try readSnapshot(from: hooksURL)
            let backupSnapshot = try readSnapshot(from: codexNotifyBackupURL)
            let backup = try decodeCodexBackup(backupSnapshot.data)

            var restoredConfig = configSnapshot.data
            if let currentData = configSnapshot.data {
                if let backup, currentData == backup.installedConfigData {
                    restoredConfig = backup.configExisted == false ? nil : backup.originalConfigData
                } else {
                    let text = try decodeText(currentData)
                    if let current = try Self.currentRootNotify(in: text), isCapsomniaNotify(current) {
                        guard let backup else { throw AIIntegrationError.missingCodexNotifyBackup }
                        restoredConfig = Data(try Self.restoringRootNotify(in: text, backup: backup).utf8)
                    }
                }
            }

            var restoredHooks = hooksSnapshot.data
            if let currentData = hooksSnapshot.data {
                if let backup, currentData == backup.installedHooksData {
                    restoredHooks = backup.hooksExisted == false ? nil : backup.originalHooksData
                } else {
                    let root = try decodeJSONObject(currentData)
                    let updated = try removingCapsomniaHooks(in: root, source: "codex")
                    restoredHooks = try dataOrNilForEmptyJSONObject(updated, originalExisted: hooksSnapshot.existed)
                }
            }
            try commit([
                FileChange(url: coordinatedConfigURL, original: configSnapshot.data, replacement: restoredConfig),
                FileChange(url: hooksURL, original: hooksSnapshot.data, replacement: restoredHooks),
                FileChange(url: codexNotifyBackupURL, original: backupSnapshot.data, replacement: nil)
            ])
        }
    }

    private func ensureClaudeIntegration() throws -> Bool {
        let directory = homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        try createPrivateDirectory(directory)
        let settingsURL = directory.appendingPathComponent("settings.json")
        return try withExclusiveConfigurationLock(for: settingsURL) { coordinatedURL in
            let snapshot = try readSnapshot(from: coordinatedURL)
            let backupSnapshot = try readSnapshot(from: claudeBackupURL)
            let root = try decodeJSONObject(snapshot.data)
            let installedRoot = try replacingCapsomniaHooks(in: root, source: "claude")
            let installedData = try encodeJSONObject(installedRoot)
            let existingBackup = try decodeFileBackup(backupSnapshot.data)
            let backup: IntegrationFileBackup
            if try containsAllCapsomniaHooks(in: root, source: "claude"), let existingBackup {
                if snapshot.data == existingBackup.installedData {
                    backup = IntegrationFileBackup(
                        originalData: existingBackup.originalData,
                        installedData: installedData,
                        existed: existingBackup.existed
                    )
                } else {
                    let cleaned = try removingCapsomniaHooks(in: root, source: "claude")
                    let originalData = cleaned.isEmpty ? nil : try encodeJSONObject(cleaned)
                    backup = IntegrationFileBackup(
                        originalData: originalData,
                        installedData: installedData,
                        existed: originalData != nil
                    )
                }
            } else {
                let originalData: Data?
                let originallyExisted: Bool
                if try containsAllCapsomniaHooks(in: root, source: "claude") {
                    let cleaned = try removingCapsomniaHooks(in: root, source: "claude")
                    originalData = cleaned.isEmpty ? nil : try encodeJSONObject(cleaned)
                    originallyExisted = originalData != nil
                } else {
                    originalData = snapshot.data
                    originallyExisted = snapshot.existed
                }
                backup = IntegrationFileBackup(
                    originalData: originalData,
                    installedData: installedData,
                    existed: originallyExisted
                )
            }
            try commit([
                FileChange(url: claudeBackupURL, original: backupSnapshot.data, replacement: try encodeFileBackup(backup)),
                FileChange(url: coordinatedURL, original: snapshot.data, replacement: installedData)
            ])
            return try inspectClaudeIntegration()
        }
    }

    private func removeClaudeIntegration() throws {
        let directory = homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        let settingsURL = directory.appendingPathComponent("settings.json")
        if try pathKind(directory) == .missing {
            try removeBackupIfPresent(claudeBackupURL)
            return
        }
        try rejectSymbolicLinksInPath(directory)
        try withExclusiveConfigurationLock(for: settingsURL) { coordinatedURL in
            let snapshot = try readSnapshot(from: coordinatedURL)
            let backupSnapshot = try readSnapshot(from: claudeBackupURL)
            let backup = try decodeFileBackup(backupSnapshot.data)
            var restored = snapshot.data
            if let currentData = snapshot.data {
                if let backup, currentData == backup.installedData {
                    restored = backup.existed ? backup.originalData : nil
                } else {
                    let root = try decodeJSONObject(currentData)
                    let updated = try removingCapsomniaHooks(in: root, source: "claude")
                    restored = try dataOrNilForEmptyJSONObject(updated, originalExisted: snapshot.existed)
                }
            }
            try commit([
                FileChange(url: coordinatedURL, original: snapshot.data, replacement: restored),
                FileChange(url: claudeBackupURL, original: backupSnapshot.data, replacement: nil)
            ])
        }
    }

    private func inspectCodexIntegration() throws -> Bool {
        let directory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        let configURL = directory.appendingPathComponent("config.toml")
        let hooksURL = directory.appendingPathComponent("hooks.json")
        let config = try decodeText(readSnapshot(from: configURL).data)
        guard try Self.codexHooksAreEnabled(in: config) else { return false }
        guard let notify = try Self.currentRootNotify(in: config), isCapsomniaNotify(notify) else { return false }
        let hooks = try decodeJSONObject(readSnapshot(from: hooksURL).data)
        return try containsAllCapsomniaHooks(in: hooks, source: "codex")
    }

    private func inspectClaudeIntegration() throws -> Bool {
        let url = homeDirectory.appendingPathComponent(".claude/settings.json")
        let root = try decodeJSONObject(readSnapshot(from: url).data)
        if root["disableAllHooks"] as? Bool == true { return false }
        return try containsAllCapsomniaHooks(in: root, source: "claude")
    }

    private static let lifecycleHookEvents = AIActivityEventKind.allCases.map(\.rawValue)

    private func replacingCapsomniaHooks(in root: [String: Any], source: String) throws -> [String: Any] {
        var updated = try removingCapsomniaHooks(in: root, source: source)
        var hooks: [String: Any]
        if let existing = updated["hooks"] {
            guard let value = existing as? [String: Any] else { throw AIIntegrationError.invalidConfiguration }
            hooks = value
        } else {
            hooks = [:]
        }
        for event in Self.lifecycleHookEvents {
            let groups: [[String: Any]]
            if let existing = hooks[event] {
                guard let value = existing as? [[String: Any]] else { throw AIIntegrationError.invalidConfiguration }
                groups = value
            } else {
                groups = []
            }
            hooks[event] = groups + [[
                "hooks": [[
                    "type": "command",
                    "command": lifecycleHookCommand(source: source),
                    "timeout": 10
                ]]
            ]]
        }
        updated["hooks"] = hooks
        return updated
    }

    private func removingCapsomniaHooks(in root: [String: Any], source: String) throws -> [String: Any] {
        var updated = root
        guard var hooks = updated["hooks"] as? [String: Any] else {
            if updated["hooks"] != nil { throw AIIntegrationError.invalidConfiguration }
            return updated
        }
        for event in Self.lifecycleHookEvents {
            guard let existing = hooks[event] else { continue }
            guard let groups = existing as? [[String: Any]] else { throw AIIntegrationError.invalidConfiguration }
            let filtered = groups.compactMap { group -> [String: Any]? in
                guard var handlers = group["hooks"] as? [[String: Any]] else { return group }
                handlers.removeAll { handler in
                    guard let command = handler["command"] as? String else { return false }
                    return isCapsomniaLifecycleHookCommand(command, source: source)
                }
                guard !handlers.isEmpty else { return nil }
                var replacement = group
                replacement["hooks"] = handlers
                return replacement
            }
            if filtered.isEmpty { hooks.removeValue(forKey: event) }
            else { hooks[event] = filtered }
        }
        if hooks.isEmpty { updated.removeValue(forKey: "hooks") }
        else { updated["hooks"] = hooks }
        return updated
    }

    private func containsAllCapsomniaHooks(in root: [String: Any], source: String) throws -> Bool {
        guard let hooks = root["hooks"] as? [String: Any] else {
            if root["hooks"] != nil { throw AIIntegrationError.invalidConfiguration }
            return false
        }
        for event in Self.lifecycleHookEvents {
            guard let groups = hooks[event] as? [[String: Any]] else { return false }
            let found = groups.contains { group in
                guard Set(group.keys) == ["hooks"],
                      group["matcher"] == nil,
                      let handlers = group["hooks"] as? [[String: Any]] else { return false }
                return handlers.contains { handler in
                    guard Set(handler.keys) == ["type", "command", "timeout"],
                          handler["type"] as? String == "command",
                          let command = handler["command"] as? String,
                          let timeout = handler["timeout"] as? NSNumber,
                          timeout.intValue == 10 else { return false }
                    return command == lifecycleHookCommand(source: source)
                }
            }
            if !found { return false }
        }
        return true
    }

    private static func codexHooksAreEnabled(in config: String) throws -> Bool {
        var currentTable: [String] = []
        var sawHooksValue = false
        for rawLine in config.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            let content = tomlContentBeforeComment(String(rawLine))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { continue }

            if content.hasPrefix("[") {
                let isArrayTable = content.hasPrefix("[[")
                let openingCount = isArrayTable ? 2 : 1
                let closing = isArrayTable ? "]]" : "]"
                guard content.hasSuffix(closing),
                      content.count > openingCount + closing.count else {
                    throw AIIntegrationError.invalidConfiguration
                }
                let start = content.index(content.startIndex, offsetBy: openingCount)
                let end = content.index(content.endIndex, offsetBy: -closing.count)
                guard let path = tomlKeyPath(String(content[start..<end])) else {
                    throw AIIntegrationError.invalidConfiguration
                }
                if isArrayTable, path == ["features"] { return false }
                currentTable = path
                continue
            }

            guard let assignment = tomlAssignment(content),
                  let localPath = tomlKeyPath(assignment.key) else {
                throw AIIntegrationError.invalidConfiguration
            }
            let effectivePath = currentTable + localPath
            if effectivePath == ["features"] {
                // Inline-table/scalar feature definitions are legal TOML, but
                // this conservative reader intentionally declines to infer them.
                return false
            }
            guard effectivePath == ["features", "hooks"]
                    || effectivePath == ["features", "codex_hooks"] else {
                continue
            }
            guard !sawHooksValue else { return false }
            sawHooksValue = true
            switch assignment.value.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true": continue
            case "false": return false
            default: return false
            }
        }
        return true
    }

    private static func tomlContentBeforeComment(_ line: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if inDoubleQuote {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inDoubleQuote = false }
            } else if inSingleQuote {
                if character == "'" { inSingleQuote = false }
            } else if character == "\"" {
                inDoubleQuote = true
            } else if character == "'" {
                inSingleQuote = true
            } else if character == "#" {
                return String(line[..<index])
            }
            index = line.index(after: index)
        }
        return line
    }

    private static func tomlAssignment(_ content: String) -> (key: String, value: String)? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false
        var index = content.startIndex
        while index < content.endIndex {
            let character = content[index]
            if inDoubleQuote {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inDoubleQuote = false }
            } else if inSingleQuote {
                if character == "'" { inSingleQuote = false }
            } else if character == "\"" {
                inDoubleQuote = true
            } else if character == "'" {
                inSingleQuote = true
            } else if character == "=" {
                let valueStart = content.index(after: index)
                return (
                    String(content[..<index]).trimmingCharacters(in: .whitespaces),
                    String(content[valueStart...]).trimmingCharacters(in: .whitespaces)
                )
            }
            index = content.index(after: index)
        }
        return nil
    }

    private static func tomlKeyPath(_ raw: String) -> [String]? {
        let characters = Array(raw)
        var result: [String] = []
        var index = 0
        func isWhitespace(_ character: Character) -> Bool {
            character == " " || character == "\t"
        }
        while true {
            while index < characters.count, isWhitespace(characters[index]) { index += 1 }
            guard index < characters.count else { return result.isEmpty ? nil : result }

            let segment: String
            if characters[index] == "\"" {
                let start = index
                index += 1
                var escaped = false
                while index < characters.count {
                    let character = characters[index]
                    index += 1
                    if escaped { escaped = false; continue }
                    if character == "\\" { escaped = true; continue }
                    if character == "\"" { break }
                }
                guard index <= characters.count,
                      characters[index - 1] == "\"" else { return nil }
                let literal = String(characters[start..<index])
                guard let data = "[\(literal)]".data(using: .utf8),
                      let values = try? JSONSerialization.jsonObject(with: data) as? [String],
                      let value = values.first else { return nil }
                segment = value
            } else if characters[index] == "'" {
                index += 1
                let start = index
                while index < characters.count, characters[index] != "'" { index += 1 }
                guard index < characters.count else { return nil }
                segment = String(characters[start..<index])
                index += 1
            } else {
                let start = index
                while index < characters.count {
                    let character = characters[index]
                    if character.isLetter || character.isNumber || character == "_" || character == "-" {
                        index += 1
                    } else {
                        break
                    }
                }
                guard index > start else { return nil }
                segment = String(characters[start..<index])
            }
            guard !segment.isEmpty else { return nil }
            result.append(segment)
            while index < characters.count, isWhitespace(characters[index]) { index += 1 }
            if index == characters.count { return result }
            guard characters[index] == "." else { return nil }
            index += 1
        }
    }

    private func lifecycleHookCommand(source: String) -> String {
        "\(shellQuote(bridgeExecutableURL.path)) \(source)-hook"
    }

    private func isCapsomniaLifecycleHookCommand(_ command: String, source: String) -> Bool {
        let paths = [
            bridgeExecutableURL.path,
            "/Applications/Capsomnia.app/Contents/Resources/\(Self.bridgeExecutableName)",
            homeDirectory.appendingPathComponent("Applications/Capsomnia.app/Contents/Resources/\(Self.bridgeExecutableName)").path
        ]
        let suffixes = ["\(source)-hook", source]
        return paths.contains { path in
            suffixes.contains { suffix in command == "\(shellQuote(path)) \(suffix)" }
        }
    }

    private func isCapsomniaNotify(_ command: [String]) -> Bool {
        guard command.count >= 2 else { return false }
        let commandPath = URL(fileURLWithPath: command[0]).standardizedFileURL.path
        let knownPaths = [
            bridgeExecutableURL.standardizedFileURL.path,
            "/Applications/Capsomnia.app/Contents/Resources/\(Self.bridgeExecutableName)",
            homeDirectory
                .appendingPathComponent("Applications/Capsomnia.app/Contents/Resources")
                .appendingPathComponent(Self.bridgeExecutableName)
                .standardizedFileURL.path
        ]
        return knownPaths.contains(commandPath) && command[1] == "codex"
    }

    private static func currentRootNotify(in config: String) throws -> [String]? {
        guard let match = try rootNotifyMatch(in: config),
              let range = Range(match.valueRange, in: config),
              let value = parseNotifyArray(String(config[range])) else { return nil }
        return value
    }

    private static func rootNotifyLine(in config: String) throws -> String? {
        guard let match = try rootNotifyMatch(in: config),
              let range = Range(match.lineRange, in: config) else { return nil }
        return String(config[range])
    }

    private static func restoringRootNotify(in config: String, backup: CodexNotifyBackup) throws -> String {
        guard let match = try rootNotifyMatch(in: config),
              let range = Range(match.lineRange, in: config) else { return config }
        var updated = config
        if let originalLine = backup.originalNotifyLine {
            updated.replaceSubrange(range, with: originalLine)
        } else if let originalNotify = backup.originalNotify {
            let newline = config.contains("\r\n") ? "\r\n" : "\n"
            updated.replaceSubrange(range, with: "notify = \(tomlArray(originalNotify))\(newline)")
        } else {
            updated.removeSubrange(range)
        }
        return updated
    }

    private struct RootNotifyMatch {
        let lineRange: NSRange
        let valueRange: NSRange
    }

    private static func rootNotifyMatch(in config: String) throws -> RootNotifyMatch? {
        let text = config as NSString
        let notifyRegex = try NSRegularExpression(
            pattern: #"^[ \t]*notify[ \t]*=[ \t]*(\[[^\r\n]*\])[ \t]*(?:#.*)?(?:\r?\n)?$"#
        )
        let tableRegex = try NSRegularExpression(
            pattern: #"^[ \t]*(?:\[[^\[\]\r\n]+\]|\[\[[^\[\]\r\n]+\]\])[ \t]*(?:#.*)?(?:\r?\n)?$"#
        )
        var location = 0
        var inRoot = true
        var found: RootNotifyMatch?
        while location < text.length {
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            let line = text.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") {
                let full = NSRange(location: 0, length: (line as NSString).length)
                guard tableRegex.firstMatch(in: line, range: full) != nil else {
                    throw AIIntegrationError.invalidConfiguration
                }
                inRoot = false
            } else if inRoot {
                let full = NSRange(location: 0, length: (line as NSString).length)
                if let match = notifyRegex.firstMatch(in: line, range: full) {
                    guard found == nil else { throw AIIntegrationError.invalidConfiguration }
                    found = RootNotifyMatch(
                        lineRange: lineRange,
                        valueRange: NSRange(
                            location: lineRange.location + match.range(at: 1).location,
                            length: match.range(at: 1).length
                        )
                    )
                } else if trimmed.range(of: #"^notify(?:\s|=)"#, options: .regularExpression) != nil {
                    throw AIIntegrationError.unsupportedCodexNotifyFormat
                }
            }
            let next = NSMaxRange(lineRange)
            if next <= location { break }
            location = next
        }
        return found
    }

    private func prepareSupportDirectory() throws { try createPrivateDirectory(supportDirectoryURL) }

    private func createPrivateDirectory(_ url: URL) throws {
        try rejectSymbolicLinksInPath(url)
        if try pathKind(url) == .missing {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            try rejectSymbolicLinksInPath(url)
        }
        var value = stat()
        guard Darwin.lstat(url.path, &value) == 0, (value.st_mode & S_IFMT) == S_IFDIR else {
            throw AIIntegrationError.invalidConfiguration
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func rejectSymbolicLinksInPath(_ url: URL) throws {
        let root = homeDirectory.standardizedFileURL
        let target = url.standardizedFileURL
        guard target.path == root.path || target.path.hasPrefix(root.path + "/") else {
            throw AIIntegrationError.invalidConfiguration
        }
        var current = root
        if try pathKind(current) == .symbolicLink {
            throw AIIntegrationError.symbolicLinkNotSupported(current.path)
        }
        let relative = target.path.dropFirst(root.path.count)
        for component in relative.split(separator: "/").map(String.init) {
            current.appendPathComponent(component)
            if try pathKind(current) == .symbolicLink {
                throw AIIntegrationError.symbolicLinkNotSupported(current.path)
            }
        }
    }

    private func pathKind(_ url: URL) throws -> ManagedPathKind {
        var value = stat()
        if Darwin.lstat(url.path, &value) == 0 {
            return (value.st_mode & S_IFMT) == S_IFLNK ? .symbolicLink : .other
        }
        if errno == ENOENT { return .missing }
        throw AIIntegrationError.invalidConfiguration
    }

    private struct FileSnapshot {
        let data: Data?
        let existed: Bool
    }

    private struct FileChange {
        let url: URL
        let original: Data?
        let replacement: Data?
    }

    private func readSnapshot(from url: URL) throws -> FileSnapshot {
        try rejectSymbolicLinksInPath(url)
        switch try pathKind(url) {
        case .missing:
            return FileSnapshot(data: nil, existed: false)
        case .symbolicLink:
            throw AIIntegrationError.symbolicLinkNotSupported(url.path)
        case .other:
            let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW)
            guard descriptor >= 0 else { throw AIIntegrationError.invalidConfiguration }
            defer { Darwin.close(descriptor) }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
            return FileSnapshot(data: handle.readDataToEndOfFile(), existed: true)
        }
    }

    private func commit(_ changes: [FileChange]) throws {
        let effective = changes.filter { $0.original != $0.replacement }
        for change in effective { try verifyUnchanged(change.url, expectedData: change.original) }
        var attempted: [FileChange] = []
        do {
            for (index, change) in effective.enumerated() {
#if DEBUG
                try transactionWriteObserver?(index, change.url)
#endif
                try coordinatedConditionalReplace(change)
                attempted.append(change)
            }
        } catch {
            var rollbackFailed = false
            for change in attempted.reversed() {
                do {
                    try coordinatedConditionalReplace(
                        FileChange(
                            url: change.url,
                            original: change.replacement,
                            replacement: change.original
                        )
                    )
                } catch {
                    rollbackFailed = true
                }
            }
            if rollbackFailed { throw AIIntegrationError.transactionRollbackFailed }
            throw error
        }
    }

    private func coordinatedConditionalReplace(_ change: FileChange) throws {
        // The swap itself is the compare-and-swap boundary and also protects
        // against writers that do not participate in NSFileCoordinator.
        try conditionalReplace(change)
    }

    // A plain atomic write can still overwrite an external edit made after a
    // compare. Swap/move the target first, then verify the displaced bytes. If
    // they are not the expected snapshot, restore without overwriting any newer
    // writer and fail the whole multi-file transaction.
    private func conditionalReplace(_ change: FileChange) throws {
        try rejectSymbolicLinksInPath(change.url.deletingLastPathComponent())
        if try pathKind(change.url) == .symbolicLink {
            throw AIIntegrationError.symbolicLinkNotSupported(change.url.path)
        }
        let temporaryURL = change.url.deletingLastPathComponent().appendingPathComponent(
            ".capsomnia-swap-\(UUID().uuidString)"
        )
        var preserveTemporaryForRecovery = false
        defer {
            if !preserveTemporaryForRecovery,
               (try? pathKind(temporaryURL)) != .missing {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        if let replacement = change.replacement {
            try replacement.write(to: temporaryURL, options: [.withoutOverwriting])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)

            if change.original == nil {
                guard Darwin.renamex_np(temporaryURL.path, change.url.path, UInt32(RENAME_EXCL)) == 0 else {
                    throw AIIntegrationError.configurationChangedDuringUpdate
                }
                return
            }

            guard Darwin.renamex_np(temporaryURL.path, change.url.path, UInt32(RENAME_SWAP)) == 0 else {
                throw AIIntegrationError.configurationChangedDuringUpdate
            }
            let displaced = try readSnapshot(from: temporaryURL).data
            guard displaced == change.original else {
                #if DEBUG
                try transactionWriteObserver?(-1, change.url)
                #endif
                let currentRecoveryURL = change.url.deletingLastPathComponent().appendingPathComponent(
                    ".capsomnia-current-recovery-\(UUID().uuidString)"
                )
                var preserveCurrentRecovery = false
                defer {
                    if !preserveCurrentRecovery,
                       (try? pathKind(currentRecoveryURL)) != .missing {
                        try? fileManager.removeItem(at: currentRecoveryURL)
                    }
                }

                guard Darwin.renamex_np(
                    change.url.path,
                    currentRecoveryURL.path,
                    UInt32(RENAME_EXCL)
                ) == 0 else {
                    preserveTemporaryForRecovery = true
                    throw AIIntegrationError.transactionRollbackFailed
                }
                let current = try readSnapshot(from: currentRecoveryURL).data
                if current == change.replacement {
                    guard Darwin.renamex_np(
                        temporaryURL.path,
                        change.url.path,
                        UInt32(RENAME_EXCL)
                    ) == 0 else {
                        preserveTemporaryForRecovery = true
                        preserveCurrentRecovery = true
                        throw AIIntegrationError.transactionRollbackFailed
                    }
                    try fileManager.removeItem(at: currentRecoveryURL)
                    throw AIIntegrationError.configurationChangedDuringUpdate
                }

                // A second writer changed the target after the first swap.
                // Restore its latest bytes to the now-empty target, retain the
                // earlier displaced edit in the sidecar, and fail without loss.
                guard Darwin.renamex_np(
                    currentRecoveryURL.path,
                    change.url.path,
                    UInt32(RENAME_EXCL)
                ) == 0 else {
                    preserveTemporaryForRecovery = true
                    preserveCurrentRecovery = true
                    throw AIIntegrationError.transactionRollbackFailed
                }
                preserveTemporaryForRecovery = true
                preserveCurrentRecovery = false
                throw AIIntegrationError.transactionRollbackFailed
            }
            try fileManager.removeItem(at: temporaryURL)
            return
        }

        guard change.original != nil else { return }
        guard Darwin.renamex_np(change.url.path, temporaryURL.path, UInt32(RENAME_EXCL)) == 0 else {
            throw AIIntegrationError.configurationChangedDuringUpdate
        }
        let displaced = try readSnapshot(from: temporaryURL).data
        guard displaced == change.original else {
            guard try pathKind(change.url) == .missing,
                  Darwin.renamex_np(temporaryURL.path, change.url.path, UInt32(RENAME_EXCL)) == 0 else {
                preserveTemporaryForRecovery = true
                throw AIIntegrationError.transactionRollbackFailed
            }
            throw AIIntegrationError.configurationChangedDuringUpdate
        }
        try fileManager.removeItem(at: temporaryURL)
    }

    private func verifyUnchanged(_ url: URL, expectedData: Data?) throws {
        let current = try readSnapshot(from: url).data
        guard current == expectedData else { throw AIIntegrationError.configurationChangedDuringUpdate }
    }

    private func withExclusiveConfigurationLock<T>(
        for configurationURL: URL,
        _ body: (URL) throws -> T
    ) throws -> T {
        try rejectSymbolicLinksInPath(configurationURL.deletingLastPathComponent())
        let lockURL = configurationURL.deletingLastPathComponent().appendingPathComponent(".capsomnia-config.lock")
        if try pathKind(lockURL) == .symbolicLink {
            throw AIIntegrationError.symbolicLinkNotSupported(lockURL.path)
        }
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw AIIntegrationError.configurationLockFailed(lockURL.path) }
        defer { Darwin.close(descriptor) }
        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        guard Darwin.fcntl(descriptor, F_SETLKW, &lock) == 0 else {
            throw AIIntegrationError.configurationLockFailed(lockURL.path)
        }
        defer {
            var unlock = flock()
            unlock.l_type = Int16(F_UNLCK)
            unlock.l_whence = Int16(SEEK_SET)
            _ = Darwin.fcntl(descriptor, F_SETLK, &unlock)
        }

        return try body(configurationURL)
    }

    private func decodeText(_ data: Data?) throws -> String {
        guard let data else { return "" }
        guard let text = String(data: data, encoding: .utf8) else {
            throw AIIntegrationError.invalidConfiguration
        }
        return text
    }

    private func decodeJSONObject(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIIntegrationError.invalidConfiguration
        }
        return object
    }

    private func encodeJSONObject(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func dataOrNilForEmptyJSONObject(_ object: [String: Any], originalExisted: Bool) throws -> Data? {
        if object.isEmpty, !originalExisted { return nil }
        return try encodeJSONObject(object)
    }

    private func encodeCodexBackup(_ backup: CodexNotifyBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    private func decodeCodexBackup(_ data: Data?) throws -> CodexNotifyBackup? {
        guard let data else { return nil }
        return try JSONDecoder().decode(CodexNotifyBackup.self, from: data)
    }

    private func loadCodexBackup() throws -> CodexNotifyBackup? {
        try decodeCodexBackup(readSnapshot(from: codexNotifyBackupURL).data)
    }

    private func encodeFileBackup(_ backup: IntegrationFileBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    private func decodeFileBackup(_ data: Data?) throws -> IntegrationFileBackup? {
        guard let data else { return nil }
        return try JSONDecoder().decode(IntegrationFileBackup.self, from: data)
    }

    private func removeBackupIfPresent(_ url: URL) throws {
        let snapshot = try readSnapshot(from: url)
        if snapshot.existed { try commit([FileChange(url: url, original: snapshot.data, replacement: nil)]) }
    }

    private static func tomlArray(_ values: [String]) -> String {
        let encoded = values.map { value in
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return "[\(encoded.joined(separator: ", "))]"
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private enum ManagedPathKind { case missing, symbolicLink, other }

public enum AIIntegrationError: LocalizedError, Equatable {
    case invalidConfiguration
    case unsupportedCodexNotifyFormat
    case symbolicLinkNotSupported(String)
    case missingCodexNotifyBackup
    case configurationChangedDuringUpdate
    case configurationLockFailed(String)
    case transactionRollbackFailed

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "The AI tool configuration is invalid."
        case .unsupportedCodexNotifyFormat:
            "Codex root notify uses a format Capsomnia cannot safely merge."
        case let .symbolicLinkNotSupported(path):
            "Capsomnia will not modify a symbolic-link path: \(path)"
        case .missingCodexNotifyBackup:
            "Capsomnia cannot safely restore the original Codex notifier because its backup is missing."
        case .configurationChangedDuringUpdate:
            "The AI tool configuration changed while Capsomnia was updating it. No conflicting replacement was written."
        case let .configurationLockFailed(path):
            "Capsomnia could not safely lock the AI tool configuration: \(path)"
        case .transactionRollbackFailed:
            "The AI integration transaction failed and an exact rollback could not be completed."
        }
    }
}
