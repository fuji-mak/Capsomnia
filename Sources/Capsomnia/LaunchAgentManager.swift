import Foundation

struct LaunchAgentError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

enum LaunchAgentManager {
    static func setEnabled(_ enabled: Bool) throws {
        let arguments = [
            enabled ? "enable" : "disable",
            "gui/\(getuid())/\(appLabel)"
        ]
        let result = CommandRunner.run("/bin/launchctl", arguments)
        guard result.status == 0 else {
            throw LaunchAgentError(
                message: "launchctl \(arguments.joined(separator: " ")) failed: \(result.stderr.isEmpty ? result.stdout : result.stderr)"
            )
        }
    }
}
