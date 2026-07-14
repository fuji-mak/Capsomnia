import Foundation
import IOKit
import IOKit.pwr_mgt
import CoreGraphics
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

final class ActiveSessionController {
    private var displayAssertion = IOPMAssertionID(kIOPMNullAssertionID)
    private var userActivityAssertion = IOPMAssertionID(kIOPMNullAssertionID)
    private var lastUserActivityRefresh = Date.distantPast

    func setActive(_ active: Bool) {
        if active {
            if displayAssertion == kIOPMNullAssertionID {
                IOPMAssertionCreateWithName(
                    kIOPMAssertionTypeNoDisplaySleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "Capsomnia active session" as CFString,
                    &displayAssertion
                )
            }
            refreshUserActivity()
        } else {
            releaseAssertions()
        }
    }

    func refreshUserActivity() {
        guard Date().timeIntervalSince(lastUserActivityRefresh) >= 30 else { return }
        IOPMAssertionDeclareUserActivity(
            "Capsomnia active session" as CFString,
            kIOPMUserActiveLocal,
            &userActivityAssertion
        )
        lastUserActivityRefresh = Date()
    }

    func releaseAssertions() {
        if displayAssertion != kIOPMNullAssertionID {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = IOPMAssertionID(kIOPMNullAssertionID)
        }
        if userActivityAssertion != kIOPMNullAssertionID {
            IOPMAssertionRelease(userActivityAssertion)
            userActivityAssertion = IOPMAssertionID(kIOPMNullAssertionID)
        }
        lastUserActivityRefresh = .distantPast
    }
}

final class BuiltInDisplayBrightnessController {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private var displayID: CGDirectDisplayID?
    private var savedBrightness: Float?
    private var isDimmed = false
    private let frameworkHandle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?

    init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        )
        frameworkHandle = handle
        if let symbol = handle.flatMap({ dlsym($0, "DisplayServicesGetBrightness") }) {
            getBrightness = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            getBrightness = nil
        }
        if let symbol = handle.flatMap({ dlsym($0, "DisplayServicesSetBrightness") }) {
            setBrightness = unsafeBitCast(symbol, to: SetBrightness.self)
        } else {
            setBrightness = nil
        }
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func prepare() {
        guard !isDimmed else { return }
        if displayID == nil {
            displayID = builtInDisplayID()
        }
        guard savedBrightness == nil, let id = displayID, let getBrightness else { return }
        var brightness: Float = 1
        if getBrightness(id, &brightness) == 0 {
            // Session-start fallback in case macOS makes the panel unavailable
            // before delivering the binary closed-lid state.
            savedBrightness = brightness
        }
    }

    private func captureBrightnessImmediatelyBeforeDimming() {
        guard let id = displayID, let getBrightness else { return }
        var brightness: Float = 1
        if getBrightness(id, &brightness) == 0 {
            savedBrightness = brightness
        }
    }

    @discardableResult
    func dimToZero() -> Bool {
        prepare()
        guard let id = displayID, let setBrightness else { return false }
        captureBrightnessImmediatelyBeforeDimming()
        let result = setBrightness(id, 0)
        isDimmed = result == 0
        return isDimmed
    }

    @discardableResult
    func restore() -> Bool {
        guard isDimmed, let id = displayID, let brightness = savedBrightness, let setBrightness else {
            isDimmed = false
            savedBrightness = nil
            displayID = nil
            return true
        }
        let result = setBrightness(id, brightness)
        if result == 0 {
            isDimmed = false
            savedBrightness = nil
            displayID = nil
            return true
        }
        return false
    }

    private func builtInDisplayID() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
