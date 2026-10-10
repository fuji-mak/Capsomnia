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

        terminationSemaphore.wait()
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
