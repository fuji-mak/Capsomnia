import Foundation

typealias CommandResult = (status: Int32, stdout: String, stderr: String)

private final class CommandOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newData)
    }

    func string() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

enum CommandRunner {
    static func run(_ executablePath: String, _ arguments: [String]) -> CommandResult {
        run(executablePath, arguments, timeout: nil)
    }

    static func run(_ executablePath: String, _ arguments: [String], timeout: TimeInterval?) -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutBuffer = CommandOutputBuffer()
        let stderrBuffer = CommandOutputBuffer()
        let outputGroup = DispatchGroup()
        let terminationSemaphore = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        drain(stdoutPipe.fileHandleForReading, into: stdoutBuffer, group: outputGroup)
        drain(stderrPipe.fileHandleForReading, into: stderrBuffer, group: outputGroup)

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            outputGroup.wait()
            return (-1, "", "\(error)")
        }

        if let timeout {
            if terminationSemaphore.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                if terminationSemaphore.wait(timeout: .now() + 2) == .timedOut {
                    kill(process.processIdentifier, SIGKILL)
                    terminationSemaphore.wait()
                }
                // A grandchild may keep the pipes open; never block on drain.
                _ = outputGroup.wait(timeout: .now() + 1)
                let partial = stderrBuffer.string()
                let message = "timeout after \(timeout)s"
                return (
                    -2,
                    stdoutBuffer.string(),
                    partial.isEmpty ? message : "\(message)\n\(partial)"
                )
            }
        } else {
            terminationSemaphore.wait()
        }
        outputGroup.wait()

        return (
            process.terminationStatus,
            stdoutBuffer.string(),
            stderrBuffer.string()
        )
    }

    private static func drain(
        _ handle: FileHandle,
        into buffer: CommandOutputBuffer,
        group: DispatchGroup
    ) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            defer { group.leave() }
            buffer.append(handle.readDataToEndOfFile())
        }
    }
}
