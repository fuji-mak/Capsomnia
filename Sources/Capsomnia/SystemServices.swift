import Foundation
import IOKit
import Darwin

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

        guard isEnabled() == Optional(enabled) else {
            throw LaunchAgentError(message: "launchctl did not apply the requested state")
        }
    }

    static func isEnabled() -> Bool? {
        guard let output = try? runLaunchctlForOutput([
            "print-disabled",
            "gui/\(getuid())"
        ]) else {
            return nil
        }
        return parseIsEnabled(output, label: appLabel)
    }

    static func parseIsEnabled(_ output: String, label: String) -> Bool {
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let text = String(line)
            guard text.contains("\"\(label)\"") else { continue }
            if text.contains("=> true") || text.contains("=> disabled") {
                return false
            }
            if text.contains("=> false") || text.contains("=> enabled") {
                return true
            }
        }

        // launchd treats a service omitted from the disabled-services map as enabled.
        return true
    }

    private static func runLaunchctl(_ arguments: [String]) throws {
        _ = try runLaunchctlForOutput(arguments)
    }

    private static func runLaunchctlForOutput(_ arguments: [String]) throws -> String {
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

        return read(stdoutPipe.fileHandleForReading)
    }

    private static func read(_ handle: FileHandle) -> String {
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct SingleInstanceLockError: LocalizedError {
    let operation: String
    let code: Int32

    var errorDescription: String? {
        "\(operation) failed with errno \(code)"
    }
}

final class SingleInstanceLock {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    static func acquire(atPath path: String) throws -> SingleInstanceLock? {
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
        guard descriptor >= 0 else {
            throw SingleInstanceLockError(operation: "open", code: errno)
        }

        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)

        guard Darwin.fcntl(descriptor, F_SETLK, &lock) == 0 else {
            let errorCode = errno
            Darwin.close(descriptor)
            if errorCode == EACCES || errorCode == EAGAIN {
                return nil
            }
            throw SingleInstanceLockError(operation: "fcntl", code: errorCode)
        }

        return SingleInstanceLock(descriptor: descriptor)
    }

    deinit {
        var lock = flock()
        lock.l_type = Int16(F_UNLCK)
        lock.l_whence = Int16(SEEK_SET)
        _ = Darwin.fcntl(descriptor, F_SETLK, &lock)
        Darwin.close(descriptor)
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

enum LogFileRotation {
    static let maximumSize: Int64 = 1_024 * 1_024

    static func shouldRotate(currentSize: Int64, incomingDataSize: Int) -> Bool {
        currentSize + Int64(incomingDataSize) > maximumSize
    }

    static func rotateIfNeeded(
        logURL: URL,
        incomingDataSize: Int,
        fileManager: FileManager = .default
    ) {
        guard let attributes = try? fileManager.attributesOfItem(atPath: logURL.path),
              let currentSize = attributes[.size] as? NSNumber,
              shouldRotate(currentSize: currentSize.int64Value, incomingDataSize: incomingDataSize) else {
            return
        }

        let oldLogURL = logURL.appendingPathExtension("old")
        try? fileManager.removeItem(at: oldLogURL)
        try? fileManager.moveItem(at: logURL, to: oldLogURL)
    }
}

enum SleepControlPolicy {
    static func shouldDisableSleep(enabled: Bool) -> Bool {
        enabled
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

struct PowerSourceStatus: Equatable {
    let isACPower: Bool
    let percent: Int
}

enum BatteryProtectionPolicy {
    static func shouldForceSleep(_ status: PowerSourceStatus) -> Bool {
        !status.isACPower && status.percent <= 10
    }
}

enum AutomaticSleepPhysicalPreflight {
    static func allowsSleep(
        masterEnabled: Bool,
        lidClosed: Bool?,
        requiresLowBattery: Bool,
        powerStatus: PowerSourceStatus?
    ) -> Bool {
        guard masterEnabled, lidClosed == true else { return false }
        guard requiresLowBattery else { return true }
        guard let powerStatus else { return false }
        return BatteryProtectionPolicy.shouldForceSleep(powerStatus)
    }
}

enum PowerSourceReader {
    static func status() -> PowerSourceStatus? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return parse(String(data: data, encoding: .utf8) ?? "")
    }

    static func parse(_ output: String) -> PowerSourceStatus? {
        let lowercased = output.lowercased()
        let isACPower: Bool
        if lowercased.contains("now drawing from 'ac power'") {
            isACPower = true
        } else if lowercased.contains("now drawing from 'battery power'") || lowercased.contains("now drawing from 'ups power'") {
            isACPower = false
        } else {
            return nil
        }
        let pattern = #"\b(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output),
              let percent = Int(output[range]), (0...100).contains(percent) else {
            return nil
        }
        return PowerSourceStatus(isACPower: isACPower, percent: percent)
    }
}
