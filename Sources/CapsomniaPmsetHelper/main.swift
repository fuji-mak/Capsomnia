import Darwin
import Foundation

private let usage =
    "usage: capsomnia-pmset on|off|display-sleep|indicator-hide|indicator-show\n"
private let featureFlagDirectoryPath = "/Library/Preferences/FeatureFlags/Domain"
private let featureFlagPlistPath = featureFlagDirectoryPath + "/UIKit.plist"
private let indicatorFlagKey = "redesigned_text_cursor"
private let indicatorEnabledKey = "Enabled"

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("capsomnia-pmset: \(message)\n".utf8))
    exit(70)
}

private func runPmset(_ arguments: [String]) -> Never {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = arguments

    do {
        try process.run()
        process.waitUntilExit()
        exit(process.terminationStatus)
    } catch {
        fail("could not run /usr/bin/pmset: \(error)")
    }
}

private func readFeatureFlags() -> [String: Any] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: featureFlagPlistPath)),
          let plist = try? PropertyListSerialization.propertyList(
              from: data,
              format: nil
          ) as? [String: Any] else {
        return [:]
    }
    return plist
}

private func writeFeatureFlags(_ flags: [String: Any]) {
    do {
        try FileManager.default.createDirectory(
            atPath: featureFlagDirectoryPath,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: flags,
            format: .xml,
            options: 0
        )
        let url = URL(fileURLWithPath: featureFlagPlistPath)
        try data.write(to: url, options: .atomic)
        // The app reads this file as the signed-in user to display the
        // current state, so keep it world-readable regardless of umask.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: featureFlagPlistPath
        )
    } catch {
        fail("could not write \(featureFlagPlistPath): \(error)")
    }
}

/// Suppress the Caps Lock indicator by forcing the redesigned-text-cursor
/// feature flag off, preserving any unrelated flags in the same file.
private func hideIndicator() -> Never {
    var flags = readFeatureFlags()
    var indicatorFlag = flags[indicatorFlagKey] as? [String: Any] ?? [:]
    indicatorFlag[indicatorEnabledKey] = false
    flags[indicatorFlagKey] = indicatorFlag
    writeFeatureFlags(flags)
    exit(0)
}

/// Restore the macOS default by removing only this override; the file is
/// deleted when no other flags remain in it.
private func showIndicator() -> Never {
    guard FileManager.default.fileExists(atPath: featureFlagPlistPath) else {
        exit(0)
    }

    var flags = readFeatureFlags()
    if var indicatorFlag = flags[indicatorFlagKey] as? [String: Any] {
        indicatorFlag.removeValue(forKey: indicatorEnabledKey)
        if indicatorFlag.isEmpty {
            flags.removeValue(forKey: indicatorFlagKey)
        } else {
            flags[indicatorFlagKey] = indicatorFlag
        }
    } else {
        flags.removeValue(forKey: indicatorFlagKey)
    }

    if flags.isEmpty {
        do {
            try FileManager.default.removeItem(atPath: featureFlagPlistPath)
        } catch {
            fail("could not remove \(featureFlagPlistPath): \(error)")
        }
        exit(0)
    }

    writeFeatureFlags(flags)
    exit(0)
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}

switch CommandLine.arguments[1] {
case "on":
    runPmset(["-a", "disablesleep", "1"])
case "off":
    runPmset(["-a", "disablesleep", "0"])
case "display-sleep":
    runPmset(["displaysleepnow"])
case "indicator-hide":
    hideIndicator()
case "indicator-show":
    showIndicator()
default:
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}
