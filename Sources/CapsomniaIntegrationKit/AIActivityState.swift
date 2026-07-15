import Darwin
import Foundation

public enum AIActivityEventKind: String, Codable, CaseIterable {
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
}

public struct AIActivityEvent: Equatable {
    public let source: String
    public let kind: AIActivityEventKind
    public let sessionID: String
    public let turnID: String?
    public let agentID: String?
    public let hasBackgroundWork: Bool

    public init(
        source: String,
        kind: AIActivityEventKind,
        sessionID: String,
        turnID: String?,
        agentID: String?,
        hasBackgroundWork: Bool = false
    ) {
        self.source = source
        self.kind = kind
        self.sessionID = sessionID
        self.turnID = turnID
        self.agentID = agentID
        self.hasBackgroundWork = hasBackgroundWork
    }

    public var sessionKey: String { "\(source):\(sessionID)" }

    // Codex exposes a turn identifier, so a late Stop must only be able to
    // finish the exact turn that emitted it. Claude uses an exact turn when one
    // is supplied; its documented turn-less Stop is tracked at session level
    // but can only invalidate eligibility, never complete a sleep cycle.
    public var activityKey: String? {
        if source == "codex" {
            guard let turnID, !turnID.isEmpty else { return nil }
            return "\(sessionKey):\(turnID)"
        }
        if let turnID, !turnID.isEmpty {
            return "\(sessionKey):\(turnID)"
        }
        return sessionKey
    }

    public var agentKey: String? {
        guard let activityKey, let agentID, !agentID.isEmpty else { return nil }
        return "\(activityKey):agent:\(agentID)"
    }

    public var deduplicationKey: String {
        [source, kind.rawValue, sessionID, turnID ?? "", agentID ?? "", hasBackgroundWork ? "1" : "0"]
            .joined(separator: ":")
    }
}

public enum AIActivityPhase: String, Codable, Equatable {
    case running
    case permissionPending
}

public struct AITrackedActivity: Codable, Equatable {
    public var phase: AIActivityPhase
    public var updatedAt: Date

    public init(phase: AIActivityPhase, updatedAt: Date) {
        self.phase = phase
        self.updatedAt = updatedAt
    }
}

public enum AIActivityPayload {
    // Deliberately extracts identifiers and the documented background-work
    // indicators only. Prompt text, tool arguments, output, cwd, model, and
    // transcript paths are never persisted or forwarded by this layer.
    public static func event(source: String, payload: String) -> AIActivityEvent? {
        guard source == "codex" || source == "claude",
              let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawKind = object["hook_event_name"] as? String,
              let kind = AIActivityEventKind(rawValue: rawKind),
              let sessionID = string(object, keys: ["session_id", "session-id"]),
              !sessionID.isEmpty else {
            return nil
        }

        let turnID = string(object, keys: ["turn_id", "turn-id"])
        let agentID = string(object, keys: ["agent_id", "agent-id"])
        if source == "codex" && (turnID == nil || turnID?.isEmpty == true) {
            return nil
        }
        if (kind == .subagentStart || kind == .subagentStop) && (agentID == nil || agentID?.isEmpty == true) {
            return nil
        }

        var hasBackgroundWork = false
        if source == "claude", kind == .stop {
            for key in ["background_tasks", "session_crons"] where object[key] != nil {
                guard let nonEmpty = nonEmptyCollection(object[key]) else { return nil }
                hasBackgroundWork = hasBackgroundWork || nonEmpty
            }
        }

        return AIActivityEvent(
            source: source,
            kind: kind,
            sessionID: sessionID,
            turnID: turnID,
            agentID: agentID,
            hasBackgroundWork: hasBackgroundWork
        )
    }

    public static func hasClaudeBackgroundWork(payload: String) -> Bool? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var result = false
        for key in ["background_tasks", "session_crons"] where object[key] != nil {
            guard let nonEmpty = nonEmptyCollection(object[key]) else { return nil }
            result = result || nonEmpty
        }
        return result
    }

    private static func nonEmptyCollection(_ value: Any?) -> Bool? {
        if let values = value as? [Any] { return !values.isEmpty }
        if let values = value as? [String: Any] { return !values.isEmpty }
        return nil
    }

    private static func string(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }
}

public struct AIActivityState: Codable, Equatable {
    public static let schemaVersion = 3
    public var schemaVersion: Int
    public var safetyEpoch: String
    public var epochStartedAt: Date
    public var persistedAt: Date?
    public var sequence: UInt64
    public var requiresFreshCycle: Bool
    public var lastProgressAt: Date?
    public var lastCompletedSource: String?
    public var activeSessions: [String: AITrackedActivity]
    public var activeSubagents: [String: AITrackedActivity]
    public var knownActivities: [String: Date]
    public var ambiguousClaudeSessions: Set<String>
    public var recentEvents: [String: Date]

    public init(
        schemaVersion: Int = AIActivityState.schemaVersion,
        safetyEpoch: String = UUID().uuidString,
        epochStartedAt: Date = Date(),
        persistedAt: Date? = nil,
        sequence: UInt64 = 0,
        requiresFreshCycle: Bool = true,
        lastProgressAt: Date? = nil,
        lastCompletedSource: String? = nil,
        activeSessions: [String: AITrackedActivity] = [:],
        activeSubagents: [String: AITrackedActivity] = [:],
        knownActivities: [String: Date] = [:],
        ambiguousClaudeSessions: Set<String> = [],
        recentEvents: [String: Date] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.safetyEpoch = safetyEpoch
        self.epochStartedAt = epochStartedAt
        self.persistedAt = persistedAt
        self.sequence = sequence
        self.requiresFreshCycle = requiresFreshCycle
        self.lastProgressAt = lastProgressAt
        self.lastCompletedSource = lastCompletedSource
        self.activeSessions = activeSessions
        self.activeSubagents = activeSubagents
        self.knownActivities = knownActivities
        self.ambiguousClaudeSessions = ambiguousClaudeSessions
        self.recentEvents = recentEvents
    }

    public static var failSafe: AIActivityState { AIActivityState() }

    public mutating func record(_ event: AIActivityEvent, at now: Date) {
        prune(now: now)
        guard let activityKey = event.activityKey else {
            beginSafetyEpoch(at: now)
            return
        }
        if let seen = recentEvents[event.deduplicationKey], now.timeIntervalSince(seen) < 2 {
            if event.source == "claude", event.kind == .userPromptSubmit {
                ambiguousClaudeSessions.insert(event.sessionKey)
                sequence &+= 1
                lastProgressAt = now
            }
            return
        }
        recentEvents[event.deduplicationKey] = now
        sequence &+= 1

        switch event.kind {
        case .userPromptSubmit:
            if event.source == "claude", activeSessions[activityKey] != nil {
                ambiguousClaudeSessions.insert(event.sessionKey)
            }
            knownActivities[activityKey] = now
            activeSessions[activityKey] = AITrackedActivity(phase: .running, updatedAt: now)
        case .permissionRequest:
            guard knownActivities[activityKey] != nil, activeSessions[activityKey] != nil else {
                beginSafetyEpoch(at: now)
                return
            }
            // Permission approval can start an arbitrarily long tool without a
            // reliable official "resumed" hook. It therefore remains active and
            // can only be cleared by exact completion evidence, never by timeout.
            activeSessions[activityKey] = AITrackedActivity(phase: .permissionPending, updatedAt: now)
            if let key = event.agentKey, activeSubagents[key] != nil {
                activeSubagents[key] = AITrackedActivity(phase: .permissionPending, updatedAt: now)
            }
        case .postToolUse:
            guard knownActivities[activityKey] != nil, activeSessions[activityKey] != nil else {
                beginSafetyEpoch(at: now)
                return
            }
            activeSessions[activityKey] = AITrackedActivity(phase: .running, updatedAt: now)
            if let key = event.agentKey, activeSubagents[key] != nil {
                activeSubagents[key] = AITrackedActivity(phase: .running, updatedAt: now)
            }
        case .subagentStart:
            guard knownActivities[activityKey] != nil,
                  activeSessions[activityKey] != nil,
                  let key = event.agentKey else {
                beginSafetyEpoch(at: now)
                return
            }
            activeSessions[activityKey] = AITrackedActivity(phase: .running, updatedAt: now)
            activeSubagents[key] = AITrackedActivity(phase: .running, updatedAt: now)
        case .subagentStop:
            guard knownActivities[activityKey] != nil,
                  let key = event.agentKey,
                  activeSubagents[key] != nil else {
                beginSafetyEpoch(at: now)
                return
            }
            activeSubagents.removeValue(forKey: key)
            completeFreshCycleIfPossible(activityKey: activityKey)
        case .stop:
            guard knownActivities[activityKey] != nil, activeSessions[activityKey] != nil else {
                beginSafetyEpoch(at: now)
                return
            }
            if event.source == "claude", event.hasBackgroundWork {
                activeSessions[activityKey] = AITrackedActivity(phase: .running, updatedAt: now)
                lastProgressAt = now
                return
            }
            if event.source == "claude", event.turnID == nil {
                // A turn-less Claude Stop cannot be proven to belong to the
                // currently active prompt. Treat it as a new uncertainty epoch;
                // never let a delayed old Stop end newer work by timeout.
                beginSafetyEpoch(at: now)
                return
            }
            if event.source == "claude", ambiguousClaudeSessions.contains(event.sessionKey) {
                beginSafetyEpoch(at: now)
                return
            }
            activeSessions.removeValue(forKey: activityKey)
            lastCompletedSource = event.source
            completeFreshCycleIfPossible(activityKey: activityKey)
        }
        lastProgressAt = now
    }

    public mutating func beginSafetyEpoch(at now: Date) {
        schemaVersion = Self.schemaVersion
        safetyEpoch = UUID().uuidString
        epochStartedAt = now
        persistedAt = nil
        sequence &+= 1
        requiresFreshCycle = true
        lastProgressAt = now
        lastCompletedSource = nil
        activeSessions.removeAll()
        activeSubagents.removeAll()
        knownActivities.removeAll()
        ambiguousClaudeSessions.removeAll()
        recentEvents.removeAll()
    }

    public func decision(at now: Date, quietPeriod: TimeInterval) -> AIActivityDecision {
        guard schemaVersion == Self.schemaVersion else { return .unsafe }
        if !ambiguousClaudeSessions.isEmpty { return .unsafe }
        if !activeSessions.isEmpty || !activeSubagents.isEmpty { return .running }
        guard !requiresFreshCycle,
              let lastProgressAt,
              now >= lastProgressAt else { return .unsafe }
        if now.timeIntervalSince(lastProgressAt) < quietPeriod { return .waiting }
        return .eligible
    }

    private mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-600)
        recentEvents = recentEvents.filter { $0.value >= cutoff }
        // Never age out active work. Missing Stop evidence is sticky.
        knownActivities = knownActivities.filter {
            $0.value >= cutoff || activeSessions[$0.key] != nil
        }
    }

    private mutating func completeFreshCycleIfPossible(activityKey: String) {
        if requiresFreshCycle,
           knownActivities[activityKey] != nil,
           activeSessions.isEmpty,
           activeSubagents.isEmpty,
           ambiguousClaudeSessions.isEmpty {
            requiresFreshCycle = false
        }
    }
}

public enum AIActivityDecision: Equatable { case unsafe, running, waiting, eligible }

public final class AIActivityStore {
    public static let stateFilename = "ai-activity-state.json"
    private let stateURL: URL
    private let securityRootURL: URL
    private let fileManager: FileManager

    public init(
        supportDirectoryURL: URL,
        securityRootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        stateURL = supportDirectoryURL.appendingPathComponent(Self.stateFilename)
        self.securityRootURL = securityRootURL ?? supportDirectoryURL.deletingLastPathComponent()
        self.fileManager = fileManager
    }

    @discardableResult
    public func record(_ event: AIActivityEvent, at now: Date = Date()) -> AIActivityState? {
        try? withLock {
            try withWriteBarrier(at: now) {
                var state = try readState() ?? .failSafe
                state.record(event, at: now)
                try write(&state, at: now)
                return state
            }
        }
    }

    @discardableResult
    public func establishSafetyBarrier(at now: Date = Date()) -> AIActivityState? {
        try? withLock {
            try withWriteBarrier(at: now) {
                var state = AIActivityState.failSafe
                state.beginSafetyEpoch(at: now)
                try write(&state, at: now)
                return state
            }
        }
    }

    @discardableResult
    public func markUncertain(at now: Date = Date()) -> AIActivityState? {
        establishSafetyBarrier(at: now)
    }

    public func load() -> AIActivityState? {
        try? withLock { try readState() }
    }

    public func loadIfWriteBarrierClear() -> AIActivityState? {
        try? withLock {
            guard try pathKind(writeBarrierURL) == .missing else {
                throw AIActivityStoreError.writeBarrierPresent
            }
            return try readState()
        }
    }

    private var writeBarrierURL: URL {
        stateURL.deletingLastPathComponent().appendingPathComponent(".capsomnia-ai-write-in-progress")
    }

    private func withWriteBarrier<T>(at now: Date, _ body: () throws -> T) throws -> T {
        if try pathKind(writeBarrierURL) == .symbolicLink { throw AIActivityStoreError.symbolicLink }
        let descriptor = Darwin.open(
            writeBarrierURL.path,
            O_CREAT | O_WRONLY | O_TRUNC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw AIActivityStoreError.writeBarrierFailed }
        let marker = Data("\(now.timeIntervalSince1970)\n".utf8)
        let wroteMarker = marker.withUnsafeBytes { bytes in
            Darwin.write(descriptor, bytes.baseAddress, bytes.count)
        }
        let closeResult = Darwin.close(descriptor)
        guard wroteMarker == marker.count, closeResult == 0 else {
            throw AIActivityStoreError.writeBarrierFailed
        }
        do {
            let result = try body()
            guard try pathKind(writeBarrierURL) == .other else {
                throw AIActivityStoreError.writeBarrierFailed
            }
            try fileManager.removeItem(at: writeBarrierURL)
            return result
        } catch {
            // Deliberately leave the marker behind. A later successful app-owned
            // safety barrier may clear it; sleep preflight must reject it now.
            throw error
        }
    }

    private func readState() throws -> AIActivityState? {
        switch try pathKind(stateURL) {
        case .missing:
            return nil
        case .symbolicLink:
            throw AIActivityStoreError.symbolicLink
        case .other:
            break
        }
        let descriptor = Darwin.open(stateURL.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw AIActivityStoreError.invalidState }
        defer { Darwin.close(descriptor) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        let state = try JSONDecoder().decode(AIActivityState.self, from: handle.readDataToEndOfFile())
        guard state.schemaVersion == AIActivityState.schemaVersion else { throw AIActivityStoreError.invalidState }
        return state
    }

    private func write(_ state: inout AIActivityState, at now: Date) throws {
        try prepareDirectory()
        if try pathKind(stateURL) == .symbolicLink { throw AIActivityStoreError.symbolicLink }
        state.persistedAt = now
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL, options: .atomic)
        if try pathKind(stateURL) == .symbolicLink { throw AIActivityStoreError.symbolicLink }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try prepareDirectory()
        let lockURL = stateURL.deletingLastPathComponent().appendingPathComponent(".capsomnia-ai-state.lock")
        if try pathKind(lockURL) == .symbolicLink { throw AIActivityStoreError.symbolicLink }
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw AIActivityStoreError.lockFailed }
        defer { Darwin.close(descriptor) }
        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        guard Darwin.fcntl(descriptor, F_SETLKW, &lock) == 0 else { throw AIActivityStoreError.lockFailed }
        defer {
            var unlock = flock()
            unlock.l_type = Int16(F_UNLCK)
            unlock.l_whence = Int16(SEEK_SET)
            _ = Darwin.fcntl(descriptor, F_SETLK, &unlock)
        }
        return try body()
    }

    private func prepareDirectory() throws {
        let directory = stateURL.deletingLastPathComponent()
        try rejectSymbolicLinksInPath(directory)
        switch try pathKind(directory) {
        case .missing:
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try rejectSymbolicLinksInPath(directory)
        case .symbolicLink:
            throw AIActivityStoreError.symbolicLink
        case .other:
            var value = stat()
            guard Darwin.lstat(directory.path, &value) == 0, (value.st_mode & S_IFMT) == S_IFDIR else {
                throw AIActivityStoreError.symbolicLink
            }
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func rejectSymbolicLinksInPath(_ url: URL) throws {
        let root = securityRootURL.standardizedFileURL
        let target = url.standardizedFileURL
        guard target.path == root.path || target.path.hasPrefix(root.path + "/") else {
            throw AIActivityStoreError.symbolicLink
        }
        var current = root
        if try pathKind(current) == .symbolicLink { throw AIActivityStoreError.symbolicLink }
        let relative = target.path.dropFirst(root.path.count)
        for component in relative.split(separator: "/").map(String.init) {
            current.appendPathComponent(component)
            if try pathKind(current) == .symbolicLink { throw AIActivityStoreError.symbolicLink }
        }
    }

    private func pathKind(_ url: URL) throws -> AIPathKind {
        var value = stat()
        if Darwin.lstat(url.path, &value) == 0 {
            return (value.st_mode & S_IFMT) == S_IFLNK ? .symbolicLink : .other
        }
        if errno == ENOENT { return .missing }
        throw AIActivityStoreError.invalidState
    }
}

private enum AIPathKind { case missing, symbolicLink, other }
private enum AIActivityStoreError: Error {
    case symbolicLink, invalidState, lockFailed, writeBarrierPresent, writeBarrierFailed
}
