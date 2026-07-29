import CoreGraphics
import Foundation
import IOKit
import IOKit.ps

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

/// A point-in-time read of the power source, via IOKit power sources (no subprocess).
enum BatteryReader {
    struct Snapshot {
        /// True when running on wall power (AC / adapter).
        let onAC: Bool
        /// Charge percentage 0-100, or nil when no internal battery reading is available.
        let percent: Int?
    }

    static func read() -> Snapshot? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        let providingType = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String?
        let onAC = providingType == kIOPSACPowerValue

        var percent: Int?
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard let current = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey as String] as? Int,
                  maximum > 0 else {
                continue
            }
            percent = Int((Double(current) / Double(maximum) * 100).rounded())
            break
        }

        return Snapshot(onAC: onAC, percent: percent)
    }
}

/// Pure, deterministic keep-awake decision: user intent with a battery-floor safety
/// override and hysteresis latch. Extracted from the app delegate so it is unit-testable.
enum BatteryFloorPolicy {
    /// - Parameters:
    ///   - intent: whether the current mode wants the Mac awake.
    ///   - batteryReadable: false when the power source could not be read at all.
    ///   - percent: charge 0-100, or nil when unknown (but power source WAS readable).
    ///   - latched: whether keep-awake is currently released because of a prior low-battery hit.
    /// - Returns: the keep-awake decision and the next latch state.
    static func decide(
        intent: Bool,
        floorEnabled: Bool,
        floorPercent: Int,
        recoverMargin: Int,
        onAC: Bool,
        percent: Int?,
        batteryReadable: Bool,
        latched: Bool
    ) -> (keepAwake: Bool, latched: Bool) {
        guard intent else { return (false, false) }
        guard floorEnabled else { return (true, false) }
        guard batteryReadable else { return (true, latched) }
        if onAC { return (true, false) }
        guard let percent else { return (true, latched) }

        if latched {
            if percent >= floorPercent + recoverMargin {
                return (true, false)
            }
            return (false, true)
        }
        if percent <= floorPercent {
            return (false, true)
        }
        return (true, false)
    }
}
