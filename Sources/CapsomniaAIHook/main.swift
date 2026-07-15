import CapsomniaIntegrationKit
import Foundation

private func readStandardInput() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

private func forwardExistingCodexNotification(payload: String) {
    let manager = AIIntegrationManager(
        bridgeExecutableURL: URL(fileURLWithPath: CommandLine.arguments[0])
    )
    guard let command = manager.forwardedCodexNotifyCommand(), let executable = command.first else {
        return
    }

    let process = Process()
    if executable.hasPrefix("/") {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst()) + [payload]
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command + [payload]
    }
    var environment = ProcessInfo.processInfo.environment
    environment["CAPSOMNIA_FORWARDING_CODEX_NOTIFY"] = "1"
    process.environment = environment
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
        }
    } catch {
        // A failed pre-existing notifier must not block Capsomnia's completion event.
    }
}

guard CommandLine.arguments.count >= 2 else {
    exit(0)
}

// Any notifier launched by the original notifier inherits this marker. If it
// calls Capsomnia again, exit before posting or forwarding to prevent recursion.
if ProcessInfo.processInfo.environment["CAPSOMNIA_FORWARDING_CODEX_NOTIFY"] == "1" {
    exit(0)
}

let source = CommandLine.arguments[1].lowercased()
if source == "remove-integrations" {
    let manager = AIIntegrationManager(
        bridgeExecutableURL: URL(fileURLWithPath: CommandLine.arguments[0])
    )
    let errors = manager.removeInstalledIntegrations()
    if !errors.isEmpty {
        FileHandle.standardError.write(Data((errors.joined(separator: "\n") + "\n").utf8))
        exit(1)
    }
    exit(0)
}

guard source == "codex" || source == "claude" else {
    guard source == "codex-hook" || source == "claude-hook" else { exit(0) }
    let payload = readStandardInput()
    let activitySource = source == "codex-hook" ? "codex" : "claude"
    let manager = AIIntegrationManager(
        bridgeExecutableURL: URL(fileURLWithPath: CommandLine.arguments[0])
    )
    if let event = AIActivityPayload.event(source: activitySource, payload: payload),
       manager.activityStore.record(event) != nil {
        DistributedNotificationCenter.default().post(
            name: Notification.Name(AIIntegrationManager.activityNotificationName),
            object: AIIntegrationManager.appLabel,
            userInfo: ["source": activitySource]
        )
    } else {
        // A malformed lifecycle payload is not evidence that work ended. Persist
        // an explicit fail-safe state without retaining the payload itself.
        _ = manager.activityStore.markUncertain()
        DistributedNotificationCenter.default().post(
            name: Notification.Name(AIIntegrationManager.activityNotificationName),
            object: AIIntegrationManager.appLabel,
            userInfo: ["source": activitySource, "uncertain": true]
        )
    }
    exit(0)
}

let payload: String
if source == "codex" {
    payload = CommandLine.arguments.count >= 3 ? CommandLine.arguments.last ?? "" : ""
} else {
    payload = readStandardInput()
}

// `notify` is only a turn-completion signal. Lifecycle state, when trusted by
// the user, is the sole input to automatic sleep; keep this path for Codex
// notifier forwarding compatibility without treating it as task completion.
if source == "codex" {
    forwardExistingCodexNotification(payload: payload)
}
Thread.sleep(forTimeInterval: 0.05)
