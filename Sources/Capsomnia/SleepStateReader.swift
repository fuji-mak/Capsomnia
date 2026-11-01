import MacStateCore

/// Reads pmset without nesting the main run loop (the vendored reader uses
/// `waitUntilExit`, which re-enters timers and notifications).
enum SleepStateReader {
    static func isDisabled() -> Bool? {
        let result = CommandRunner.run("/usr/bin/pmset", ["-g"], timeout: 5)
        guard result.status == 0 else { return nil }
        return parse(result.stdout)
    }

    static func parse(_ output: String) -> Bool? {
        MacStateCore.SleepStateReader.parse(output)
    }
}
