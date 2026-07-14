import Darwin
import Foundation

public struct AIIntegrationStatus: Equatable {
    public let codexDetected: Bool
    public let codexConfigured: Bool
    public let claudeDetected: Bool
    public let claudeConfigured: Bool
    public let errors: [String]

    public init(
        codexDetected: Bool,
        codexConfigured: Bool,
        claudeDetected: Bool,
        claudeConfigured: Bool,
        errors: [String]
    ) {
        self.codexDetected = codexDetected
        self.codexConfigured = codexConfigured
        self.claudeDetected = claudeDetected
        self.claudeConfigured = claudeConfigured
        self.errors = errors
    }
}

public struct CodexNotifyBackup: Codable, Equatable {
    public let originalNotify: [String]?

    public init(originalNotify: [String]?) {
        self.originalNotify = originalNotify
    }
}

public enum AICompletionPayload {
    public static func shouldEmitCompletion(source: String, payload: String) -> Bool {
        guard source == "claude",
              let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return true
        }

        // A Stop hook can arrive while Claude still owns background work. Sleeping
        // in that state would interrupt the very task this feature is protecting.
        for key in ["background_tasks", "session_crons"] {
            if let values = object[key] as? [Any], !values.isEmpty {
                return false
            }
            if let values = object[key] as? [String: Any], !values.isEmpty {
                return false
            }
        }
        return true
    }

    public static func eventIdentifier(source: String, payload: String) -> String {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "\(source):\(UUID().uuidString)"
        }

        let session = object["session_id"] as? String
            ?? object["session-id"] as? String
        for key in ["prompt_id", "prompt-id", "turn-id", "turn_id"] {
            if let value = object[key] as? String, !value.isEmpty {
                return [source, session, value].compactMap { $0 }.joined(separator: ":")
            }
        }

        // Claude's documented Stop payload has a session ID but no turn ID. A
        // UUID prevents later turns in the same session from being discarded.
        return "\(source):\(session ?? "unknown"):\(UUID().uuidString)"
    }
}

public struct AIIntegrationManager {
    public static let appLabel = "com.github.fuji-mak.capsomnia"
    public static let completionNotificationName = "com.github.fuji-mak.capsomnia.aiTaskFinished"
    public static let bridgeExecutableName = "capsomnia-ai-hook"

    private let homeDirectory: URL
    private let bridgeExecutableURL: URL
    private let fileManager: FileManager

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        bridgeExecutableURL: URL,
        fileManager: FileManager = .default
    ) {
        self.homeDirectory = homeDirectory
        self.bridgeExecutableURL = bridgeExecutableURL
        self.fileManager = fileManager
    }

    public static func bridgeURL(in appBundleURL: URL) -> URL {
        appBundleURL
            .appendingPathComponent("Contents/Resources", isDirectory: true)
            .appendingPathComponent(bridgeExecutableName)
    }

    public var supportDirectoryURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/Capsomnia", isDirectory: true)
    }

    public var codexNotifyBackupURL: URL {
        supportDirectoryURL.appendingPathComponent("codex-notify-backup.json")
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
        }

        if codexDetected {
            do {
                codexConfigured = try ensureCodexIntegration()
            } catch {
                errors.append("codex: \(error.localizedDescription)")
            }
        }

        if claudeDetected {
            do {
                claudeConfigured = try ensureClaudeIntegration()
            } catch {
                errors.append("claude: \(error.localizedDescription)")
            }
        }

        return AIIntegrationStatus(
            codexDetected: codexDetected,
            codexConfigured: codexConfigured,
            claudeDetected: claudeDetected,
            claudeConfigured: claudeConfigured,
            errors: errors
        )
    }

    public func removeInstalledIntegrations() -> [String] {
        var errors: [String] = []
        do {
            try removeCodexIntegration()
        } catch {
            errors.append("codex: \(error.localizedDescription)")
        }
        do {
            try removeClaudeIntegration()
        } catch {
            errors.append("claude: \(error.localizedDescription)")
        }
        return errors
    }

    public func forwardedCodexNotifyCommand() -> [String]? {
        guard let data = try? Data(contentsOf: codexNotifyBackupURL),
              let backup = try? JSONDecoder().decode(CodexNotifyBackup.self, from: data),
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
        let regex = try NSRegularExpression(
            pattern: #"(?m)^[ \t]*notify[ \t]*=[ \t]*(\[[^\r\n]*\])[ \t]*(?:#.*)?(?:\r?\n|$)"#
        )
        let fullRange = NSRange(config.startIndex..<config.endIndex, in: config)
        let match = regex.firstMatch(in: config, range: fullRange)

        let replacementLine = replacement.map { "notify = \(tomlArray($0))\n" } ?? ""
        guard let match else {
            let notifyKeyRegex = try NSRegularExpression(pattern: #"(?m)^[ \t]*notify[ \t]*="#)
            if notifyKeyRegex.firstMatch(in: config, range: fullRange) != nil {
                throw AIIntegrationError.unsupportedCodexNotifyFormat
            }
            guard replacement != nil else {
                return (config, nil, false)
            }
            return (replacementLine + config, nil, true)
        }

        guard let valueRange = Range(match.range(at: 1), in: config),
              let previous = parseNotifyArray(String(config[valueRange])) else {
            throw AIIntegrationError.unsupportedCodexNotifyFormat
        }
        guard let lineRange = Range(match.range(at: 0), in: config) else {
            throw AIIntegrationError.invalidConfiguration
        }

        let existingLine = String(config[lineRange])
        if existingLine == replacementLine {
            return (config, previous, false)
        }

        var updated = config
        updated.replaceSubrange(lineRange, with: replacementLine)
        return (updated, previous, true)
    }

    private func isCodexDetected() -> Bool {
        let codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        if fileManager.fileExists(atPath: codexDirectory.path) {
            return true
        }

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
        let claudeDirectory = homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        if fileManager.fileExists(atPath: claudeDirectory.path) {
            return true
        }

        let knownPaths = [
            homeDirectory.appendingPathComponent(".local/bin/claude").path,
            homeDirectory.appendingPathComponent(".claude/local/claude").path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        return knownPaths.contains(where: fileManager.isExecutableFile(atPath:))
    }

    private func ensureCodexIntegration() throws -> Bool {
        let codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        try createPrivateDirectory(codexDirectory)

        let configURL = codexDirectory.appendingPathComponent("config.toml")
        return try withExclusiveConfigurationLock(for: configURL) {
            try rejectSymbolicLink(configURL)
            let snapshot = try readTextSnapshot(from: configURL)
            let originalText = snapshot.text
            let replacement = [bridgeExecutableURL.path, "codex"]

            if let current = try currentNotify(in: originalText), isCapsomniaNotify(current) {
                guard try loadCodexBackup() != nil else {
                    throw AIIntegrationError.missingCodexNotifyBackup
                }
                if current != replacement {
                    let result = try Self.replacingNotify(in: originalText, with: replacement)
                    try writePrivateText(result.text, to: configURL, replacing: snapshot.data)
                }
                return true
            }

            let result = try Self.replacingNotify(in: originalText, with: replacement)
            try saveCodexBackup(CodexNotifyBackup(originalNotify: result.previous))
            if result.changed {
                try writePrivateText(result.text, to: configURL, replacing: snapshot.data)
            }
            return true
        }
    }

    private func removeCodexIntegration() throws {
        let configURL = homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("config.toml")
        guard fileManager.fileExists(atPath: configURL.path) else {
            try? fileManager.removeItem(at: codexNotifyBackupURL)
            return
        }
        try withExclusiveConfigurationLock(for: configURL) {
            try rejectSymbolicLink(configURL)
            let snapshot = try readTextSnapshot(from: configURL)
            guard let current = try currentNotify(in: snapshot.text), isCapsomniaNotify(current) else {
                return
            }

            guard let backup = try loadCodexBackup() else {
                throw AIIntegrationError.missingCodexNotifyBackup
            }
            let result = try Self.replacingNotify(in: snapshot.text, with: backup.originalNotify)
            if result.changed {
                try writePrivateText(result.text, to: configURL, replacing: snapshot.data)
            }
            try? fileManager.removeItem(at: codexNotifyBackupURL)
        }
    }

    private func ensureClaudeIntegration() throws -> Bool {
        let claudeDirectory = homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        try createPrivateDirectory(claudeDirectory)
        let settingsURL = claudeDirectory.appendingPathComponent("settings.json")
        try rejectSymbolicLink(settingsURL)

        return try withExclusiveConfigurationLock(for: settingsURL) {
            let snapshot = try readJSONObjectSnapshot(from: settingsURL)
            var root = snapshot.object
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            var stopGroups = hooks["Stop"] as? [[String: Any]] ?? []
            if countCapsomniaHooks(in: stopGroups) == 1 {
                return true
            }
            stopGroups = removingCapsomniaHookGroups(from: stopGroups)
            stopGroups.append([
                "hooks": [[
                    "type": "command",
                    "command": claudeHookCommand,
                    "timeout": 10
                ]]
            ])
            hooks["Stop"] = stopGroups
            root["hooks"] = hooks
            try writePrivateJSON(root, to: settingsURL, replacing: snapshot.data)
            return true
        }
    }

    private func removeClaudeIntegration() throws {
        let settingsURL = homeDirectory
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
        guard fileManager.fileExists(atPath: settingsURL.path) else { return }
        try rejectSymbolicLink(settingsURL)

        try withExclusiveConfigurationLock(for: settingsURL) {
            let snapshot = try readJSONObjectSnapshot(from: settingsURL)
            var root = snapshot.object
            guard var hooks = root["hooks"] as? [String: Any],
                  let stopGroups = hooks["Stop"] as? [[String: Any]] else {
                return
            }

            let filtered = removingCapsomniaHookGroups(from: stopGroups)
            guard filtered.count != stopGroups.count else { return }
            if filtered.isEmpty {
                hooks.removeValue(forKey: "Stop")
            } else {
                hooks["Stop"] = filtered
            }
            if hooks.isEmpty {
                root.removeValue(forKey: "hooks")
            } else {
                root["hooks"] = hooks
            }
            try writePrivateJSON(root, to: settingsURL, replacing: snapshot.data)
        }
    }

    private func countCapsomniaHooks(in groups: [[String: Any]]) -> Int {
        groups.reduce(0) { count, group in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            return count + handlers.filter { ($0["command"] as? String) == claudeHookCommand }.count
        }
    }

    private func removingCapsomniaHookGroups(from groups: [[String: Any]]) -> [[String: Any]] {
        groups.compactMap { group in
            guard var handlers = group["hooks"] as? [[String: Any]] else {
                return group
            }
            handlers.removeAll { handler in
                guard let command = handler["command"] as? String else { return false }
                return command == claudeHookCommand
            }
            guard !handlers.isEmpty else { return nil }
            var updated = group
            updated["hooks"] = handlers
            return updated
        }
    }

    private func currentNotify(in config: String) throws -> [String]? {
        let regex = try NSRegularExpression(
            pattern: #"(?m)^[ \t]*notify[ \t]*=[ \t]*(\[[^\r\n]*\])[ \t]*(?:#.*)?$"#
        )
        let range = NSRange(config.startIndex..<config.endIndex, in: config)
        guard let match = regex.firstMatch(in: config, range: range),
              let valueRange = Range(match.range(at: 1), in: config) else {
            return nil
        }
        guard let value = Self.parseNotifyArray(String(config[valueRange])) else {
            throw AIIntegrationError.unsupportedCodexNotifyFormat
        }
        return value
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

    private var claudeHookCommand: String {
        "\(shellQuote(bridgeExecutableURL.path)) claude"
    }

    private func prepareSupportDirectory() throws {
        try createPrivateDirectory(supportDirectoryURL)
    }

    private func createPrivateDirectory(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try rejectSymbolicLink(url)
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func rejectSymbolicLink(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            throw AIIntegrationError.symbolicLinkNotSupported(url.path)
        }
    }

    private func saveCodexBackup(_ backup: CodexNotifyBackup) throws {
        try prepareSupportDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        try data.write(to: codexNotifyBackupURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: codexNotifyBackupURL.path)
    }

    private func loadCodexBackup() throws -> CodexNotifyBackup? {
        guard fileManager.fileExists(atPath: codexNotifyBackupURL.path) else { return nil }
        let data = try Data(contentsOf: codexNotifyBackupURL)
        return try JSONDecoder().decode(CodexNotifyBackup.self, from: data)
    }

    private func readTextSnapshot(from url: URL) throws -> (text: String, data: Data?) {
        guard fileManager.fileExists(atPath: url.path) else { return ("", nil) }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AIIntegrationError.invalidConfiguration
        }
        return (text, data)
    }

    private func readJSONObjectSnapshot(from url: URL) throws -> (object: [String: Any], data: Data?) {
        guard fileManager.fileExists(atPath: url.path) else { return ([:], nil) }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return ([:], data) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIIntegrationError.invalidConfiguration
        }
        return (object, data)
    }

    private func writePrivateText(_ text: String, to url: URL, replacing expectedData: Data?) throws {
        try verifyUnchanged(url, expectedData: expectedData)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func writePrivateJSON(
        _ object: [String: Any],
        to url: URL,
        replacing expectedData: Data?
    ) throws {
        try verifyUnchanged(url, expectedData: expectedData)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func verifyUnchanged(_ url: URL, expectedData: Data?) throws {
        let currentData: Data?
        if fileManager.fileExists(atPath: url.path) {
            currentData = try Data(contentsOf: url)
        } else {
            currentData = nil
        }
        guard currentData == expectedData else {
            throw AIIntegrationError.configurationChangedDuringUpdate
        }
    }

    private func withExclusiveConfigurationLock<T>(
        for configurationURL: URL,
        _ body: () throws -> T
    ) throws -> T {
        let lockURL = configurationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".capsomnia-config.lock")
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else {
            throw AIIntegrationError.configurationLockFailed(lockURL.path)
        }
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

        var coordinationError: NSError?
        var result: Result<T, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            writingItemAt: configurationURL,
            options: .forReplacing,
            error: &coordinationError
        ) { _ in
            result = Result { try body() }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result else {
            throw AIIntegrationError.configurationLockFailed(configurationURL.path)
        }
        return try result.get()
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

public enum AIIntegrationError: LocalizedError, Equatable {
    case invalidConfiguration
    case unsupportedCodexNotifyFormat
    case symbolicLinkNotSupported(String)
    case missingCodexNotifyBackup
    case configurationChangedDuringUpdate
    case configurationLockFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "The AI tool configuration is invalid."
        case .unsupportedCodexNotifyFormat:
            "Codex notify uses a format Capsomnia cannot safely merge."
        case let .symbolicLinkNotSupported(path):
            "Capsomnia will not replace a symbolic-link configuration: \(path)"
        case .missingCodexNotifyBackup:
            "Capsomnia cannot safely restore the original Codex notifier because its backup is missing."
        case .configurationChangedDuringUpdate:
            "The AI tool configuration changed while Capsomnia was updating it. No replacement was written."
        case let .configurationLockFailed(path):
            "Capsomnia could not safely lock the AI tool configuration: \(path)"
        }
    }
}
