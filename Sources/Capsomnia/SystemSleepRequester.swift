enum SystemSleepRequester {
    typealias Runner = (String, [String]) -> CommandResult

    static func request() -> CommandResult {
        request(runner: CommandRunner.run)
    }

    static func request(runner: Runner) -> CommandResult {
        runner("/usr/bin/pmset", ["sleepnow"])
    }
}
