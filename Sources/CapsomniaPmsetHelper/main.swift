import Darwin
import Foundation

private let usage =
    "usage: capsomnia-pmset on|off|display-sleep|indicator-hide|indicator-show|indicator-restore\n"

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

private func updateIndicator(_ operation: (IndicatorFeatureFlagStore) throws -> Void) -> Never {
    do {
        try operation(IndicatorFeatureFlagStore())
        exit(0)
    } catch {
        fail("could not update Caps Lock indicator setting: \(error)")
    }
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
    updateIndicator { try $0.hide() }
case "indicator-show":
    updateIndicator { try $0.show() }
case "indicator-restore":
    updateIndicator { try $0.restoreIfManaged() }
default:
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}
