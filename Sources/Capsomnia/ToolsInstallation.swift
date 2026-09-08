import Foundation

struct ToolsInstallationStatus {
    let cpsm: Bool
    let macready: Bool
    let skills: Bool

    var isComplete: Bool { cpsm && macready && skills }

    static func read(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                     bin: URL = URL(fileURLWithPath: "/usr/local/bin")) -> Self {
        let fm = FileManager.default
        let skills = ["capsomnia", "macready"].allSatisfy { name in
            let shared = home.appendingPathComponent(".agents/skills/\(name)")
            let claude = home.appendingPathComponent(".claude/skills/\(name)")
            return fm.isReadableFile(atPath: shared.appendingPathComponent("SKILL.md").path)
                && (try? fm.destinationOfSymbolicLink(atPath: claude.path)) != nil
                && claude.resolvingSymlinksInPath().standardizedFileURL == shared.resolvingSymlinksInPath().standardizedFileURL
        }
        return Self(cpsm: fm.isExecutableFile(atPath: bin.appendingPathComponent("cpsm").path),
                    macready: fm.isExecutableFile(atPath: bin.appendingPathComponent("macready").path),
                    skills: skills)
    }
}

/// Uses the signed distribution package, without opening Installer.app or exposing
/// its component choices. Skill scripts run as the logged-in user, never as root.
enum ToolsInstallation {
    enum Failure: Error { case unsupportedPackage, installationFailed, cancelled, verificationFailed }

    static let formatMarker = "CapsomniaToolsInstallFormat: 2"

    static func install(_ package: URL, onAuthorized: @escaping () -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            completion(Result {
                try validateFormat(package)
                // The privileged command starts only after authentication. Signal that
                // boundary as the user, so no root writes target a user-controlled path.
                let signalDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Capsomnia-Authorization-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: signalDirectory, withIntermediateDirectories: false,
                                                       attributes: [.posixPermissions: 0o700])
                let marker = signalDirectory.appendingPathComponent("authorized")
                let observer = observeAuthorization(marker: marker, onAuthorized: onAuthorized)
                defer {
                    observer.cancel()
                    try? FileManager.default.removeItem(at: signalDirectory)
                }
                let command = "/usr/bin/sudo -u '#\(getuid())' /usr/bin/touch \(shellQuote(marker.path)) && /usr/sbin/installer -pkg \(shellQuote(package.path)) -target /"
                let result = CommandRunner.run("/usr/bin/osascript", ["-e", appleScript(command)])
                writeLog(result)
                guard result.status == 0 else {
                    if result.stderr.contains("(-128)") { throw Failure.cancelled }
                    throw Failure.installationFailed
                }
                guard ToolsInstallationStatus.read().isComplete else { throw Failure.verificationFailed }
            })
        }
    }

    static func observeAuthorization(marker: URL, onAuthorized: @escaping () -> Void) -> DispatchSourceTimer {
        let observer = DispatchSource.makeTimerSource(queue: .main)
        observer.schedule(deadline: .now(), repeating: .milliseconds(50))
        var notified = false
        observer.setEventHandler {
            guard !notified, FileManager.default.fileExists(atPath: marker.path) else { return }
            notified = true
            onAuthorized()
        }
        observer.resume()
        return observer
    }

    static func validateFormat(_ package: URL) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Capsomnia-Tools-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = CommandRunner.run("/usr/sbin/pkgutil", ["--expand", package.path, directory.path])
        guard result.status == 0,
              let distribution = try? String(contentsOf: directory.appendingPathComponent("Distribution"), encoding: .utf8),
              distribution.contains(formatMarker) else { throw Failure.unsupportedPackage }
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScript(_ command: String) -> String {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    private static func writeLog(_ result: CommandResult) {
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        let body = "\(Date()) status=\(result.status)\n\(result.stdout)\n\(result.stderr)\n"
        try? body.write(to: logDirectoryURL.appendingPathComponent("tools-install.log"), atomically: true, encoding: .utf8)
    }
}
