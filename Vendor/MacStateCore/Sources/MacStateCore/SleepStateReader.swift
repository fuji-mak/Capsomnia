import Foundation

public enum SleepStateReader {
    /// Observes the global SleepDisabled setting, not every process assertion.
    public static func isDisabled() -> Bool? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else { return nil }
        return parse(text)
    }

    public static func parse(_ output: String) -> Bool? {
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count >= 2, fields[0].lowercased() == "sleepdisabled" else { continue }
            switch fields[1] {
            case "1": return true
            case "0": return false
            default: return nil
            }
        }
        return nil
    }
}
