import Darwin
import Foundation

private let usage = "usage: capsomnia-pmset on|off|display-sleep\n"

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}

let pmsetArguments: [String]
switch CommandLine.arguments[1] {
case "on":
    pmsetArguments = ["-a", "disablesleep", "1"]
case "off":
    pmsetArguments = ["-a", "disablesleep", "0"]
case "display-sleep":
    pmsetArguments = ["displaysleepnow"]
default:
    FileHandle.standardError.write(Data(usage.utf8))
    exit(64)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
process.arguments = pmsetArguments

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    let message = "capsomnia-pmset: could not run /usr/bin/pmset: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(70)
}
