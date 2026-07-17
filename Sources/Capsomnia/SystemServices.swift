import CoreGraphics
import Foundation
import IOKit

struct LaunchAgentError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

enum CommandRunner {
    static func run(_ executablePath: String, _ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", "\(error)")
        }

        return (
            process.terminationStatus,
            read(stdoutPipe.fileHandleForReading),
            read(stderrPipe.fileHandleForReading)
        )
    }

    private static func read(_ handle: FileHandle) -> String {
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

enum SleepStateReader {
    static func isDisabled() -> Bool? {
        let result = CommandRunner.run("/usr/bin/pmset", ["-g"])
        guard result.status == 0 else { return nil }
        return parse(result.stdout)
    }

    static func parse(_ output: String) -> Bool? {
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count >= 2,
                  fields[0].lowercased() == "sleepdisabled" else {
                continue
            }

            switch fields[1] {
            case "1": return true
            case "0": return false
            default: return nil
            }
        }

        return nil
    }
}

enum ClamshellStateReader {
    static func isClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let value = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        return (value as? NSNumber)?.boolValue
    }
}

enum ExternalDisplayReader {
    static func isConnected() -> Bool? {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else {
            return nil
        }

        guard displayCount > 0 else { return false }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else {
            return nil
        }

        return displays.prefix(Int(displayCount)).contains { CGDisplayIsBuiltin($0) == 0 }
    }
}

enum DisplaySleepPolicy {
    static func shouldRequestDisplaySleep(externalDisplayConnected: Bool?) -> Bool {
        externalDisplayConnected == false
    }
}
