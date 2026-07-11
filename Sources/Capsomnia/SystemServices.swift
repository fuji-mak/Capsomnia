import Foundation
import IOKit

struct LaunchAgentError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

enum LaunchAgentManager {
    static func setEnabled(_ enabled: Bool) throws {
        try runLaunchctl([
            enabled ? "enable" : "disable",
            "gui/\(getuid())/\(appLabel)"
        ])
    }

    private static func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = read(stderrPipe.fileHandleForReading)
            let stdout = read(stdoutPipe.fileHandleForReading)
            throw LaunchAgentError(
                message: "launchctl \(arguments.joined(separator: " ")) failed: \(stderr.isEmpty ? stdout : stderr)"
            )
        }
    }

    private static func read(_ handle: FileHandle) -> String {
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

enum SleepStateReader {
    static func isDisabled() -> Bool? {
        let process = Process()
        let stdoutPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        return parse(output)
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
