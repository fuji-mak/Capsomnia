import Darwin
import Foundation
import CryptoKit

private let controlMaxMessageBytes = 64 * 1024
private let controlSocketTimeout: TimeInterval = 5

private func controlJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}

private func socketAddress(_ path: String) throws -> (sockaddr_un, socklen_t) {
    let bytes = Array(path.utf8) + [0]
    var address = sockaddr_un()
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard bytes.count <= capacity else { throw ControlTransportError.endpointPathTooLong }
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
        destination.initializeMemory(as: UInt8.self, repeating: 0)
        for (index, byte) in bytes.enumerated() { destination[index] = byte }
    }
    return (address, socklen_t(MemoryLayout<sockaddr_un>.size))
}

private func withSockaddr<T>(
    _ address: inout sockaddr_un,
    _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
) rethrows -> T {
    try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            try body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
}

private func createSocket() throws -> Int32 {
    let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw ControlTransportError.socketCreationFailed(errno) }
    setNoSigPipe(descriptor)
    return descriptor
}

private func setNoSigPipe(_ descriptor: Int32) {
    var enabled: Int32 = 1
    _ = setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
}

private func setTimeout(_ descriptor: Int32, option: Int32, seconds: TimeInterval) {
    var timeout = timeval(
        tv_sec: Int(seconds),
        tv_usec: Int32((seconds - floor(seconds)) * 1_000_000)
    )
    _ = setsockopt(descriptor, SOL_SOCKET, option, &timeout, socklen_t(MemoryLayout<timeval>.size))
}

private func setNonBlocking(_ descriptor: Int32, _ enabled: Bool) {
    let current = fcntl(descriptor, F_GETFL, 0)
    guard current >= 0 else { return }
    _ = fcntl(descriptor, F_SETFL, enabled ? (current | O_NONBLOCK) : (current & ~O_NONBLOCK))
}

private func waitFor(_ descriptor: Int32, events: Int16, timeout: Int32) -> Bool {
    var pollDescriptor = pollfd(fd: descriptor, events: events, revents: 0)
    while true {
        let result = Darwin.poll(&pollDescriptor, 1, timeout)
        if result > 0 { return (pollDescriptor.revents & events) != 0 }
        if result == 0 || errno != EINTR { return false }
    }
}

private func writeAll(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else { return }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(descriptor, baseAddress.advanced(by: offset), bytes.count - offset)
            if count > 0 { offset += count; continue }
            if count < 0, errno == EINTR { continue }
            throw ControlTransportError.writeFailed(errno)
        }
    }
}

private func readLine(from descriptor: Int32, maxBytes: Int) throws -> Data {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while data.count <= maxBytes {
        let count = Darwin.read(descriptor, &buffer, buffer.count)
        if count > 0 {
            data.append(contentsOf: buffer[0..<count])
            if data.contains(10) {
                guard let newline = data.firstIndex(of: 10) else { throw ControlTransportError.invalidMessage }
                guard newline < maxBytes else { throw ControlTransportError.responseTooLarge }
                return data.subdata(in: 0..<newline)
            }
            if data.count > maxBytes { throw ControlTransportError.responseTooLarge }
        } else if count == 0 {
            return data
        } else if errno != EINTR {
            if errno == EAGAIN || errno == EWOULDBLOCK { throw ControlTransportError.timedOut }
            throw ControlTransportError.readFailed(errno)
        }
    }
    throw ControlTransportError.responseTooLarge
}

private func ensurePrivateDirectory(_ url: URL) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.path) {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
    // Capsomnia 3.5's updater also used this cache directory and could leave
    // it at 0755. Open the actual directory without following a symlink,
    // then check ownership before tightening permissions on that same inode.
    let descriptor = Darwin.open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else { throw ControlTransportError.unsafeEndpoint }
    defer { close(descriptor) }
    var info = stat()
    guard fstat(descriptor, &info) == 0,
          (info.st_mode & S_IFMT) == S_IFDIR,
          info.st_uid == getuid() else {
        throw ControlTransportError.unsafeEndpoint
    }
    let privateMode = mode_t(S_IRUSR | S_IWUSR | S_IXUSR)
    if (info.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO)) != privateMode {
        guard fchmod(descriptor, privateMode) == 0 else {
            throw ControlTransportError.unsafeEndpoint
        }
    }
    guard fstat(descriptor, &info) == 0,
          (info.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO)) == privateMode else {
        throw ControlTransportError.unsafeEndpoint
    }
}

private func endpointExistsAsSafeSocket(_ path: String) throws -> Bool {
    var info = stat()
    guard lstat(path, &info) == 0 else {
        if errno == ENOENT { return false }
        throw ControlTransportError.unsafeEndpoint
    }
    guard (info.st_mode & S_IFMT) == S_IFSOCK,
          info.st_uid == getuid(),
          (info.st_mode & (S_IRWXG | S_IRWXO)) == 0 else {
        throw ControlTransportError.unsafeEndpoint
    }
    return true
}

private func activeSocket(at path: String) -> Bool {
    guard let (address, _) = try? socketAddress(path),
          let descriptor = try? createSocket() else { return false }
    defer { close(descriptor) }
    var mutableAddress = address
    let result = withSockaddr(&mutableAddress) { pointer, length in
        Darwin.connect(descriptor, pointer, length)
    }
    return result == 0
}

public final class ControlServer {
    public typealias Handler = (ControlRequest, @escaping (ControlResponse) -> Void) -> Void

    private let endpointPath: String
    private let handler: Handler
    private let stateLock = NSLock()
    private var listener: Int32 = -1
    private var running = false
    private var ownsSocket = false
    private let acceptQueue = DispatchQueue(label: "com.capsomnia.control.accept")
    private let connectionQueue = DispatchQueue(label: "com.capsomnia.control.connections", attributes: .concurrent)

    public init(bundleIdentifier: String, handler: @escaping Handler) throws {
        self.endpointPath = try ControlEndpoint.path(for: bundleIdentifier)
        self.handler = handler
    }

    /// An explicit path is useful for transport tests and local previews.
    public init(endpointPath: String, handler: @escaping Handler) throws {
        guard endpointPath.utf8.count < 104 else { throw ControlTransportError.endpointPathTooLong }
        self.endpointPath = endpointPath
        self.handler = handler
    }

    deinit { stop() }

    public func start() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !running else { return }

        let directory = URL(fileURLWithPath: endpointPath).deletingLastPathComponent()
        try ensurePrivateDirectory(directory)
        if try endpointExistsAsSafeSocket(endpointPath) {
            if activeSocket(at: endpointPath) { throw ControlTransportError.endpointAlreadyRunning }
            _ = unlink(endpointPath)
        }

        let descriptor = try createSocket()
        var address = try socketAddress(endpointPath).0
        let bindResult = withSockaddr(&address) { pointer, length in
            Darwin.bind(descriptor, pointer, length)
        }
        guard bindResult == 0 else {
            let code = errno
            close(descriptor)
            throw ControlTransportError.connectFailed(code)
        }
        _ = chmod(endpointPath, mode_t(S_IRUSR | S_IWUSR))
        guard Darwin.listen(descriptor, 8) == 0 else {
            let code = errno
            close(descriptor)
            _ = unlink(endpointPath)
            throw ControlTransportError.connectFailed(code)
        }
        listener = descriptor
        running = true
        ownsSocket = true
        acceptQueue.async { [weak self] in self?.acceptLoop() }
    }

    public func stop() {
        stateLock.lock()
        let descriptor = listener
        listener = -1
        let shouldRemove = ownsSocket
        ownsSocket = false
        running = false
        stateLock.unlock()

        if descriptor >= 0 { close(descriptor) }
        if shouldRemove {
            // Only remove a socket created by this server and only when it is
            // still a same-user socket. Never unlink arbitrary user files.
            if (try? endpointExistsAsSafeSocket(endpointPath)) == true {
                _ = unlink(endpointPath)
            }
        }
    }

    private func acceptLoop() {
        stateLock.lock()
        let descriptor = listener
        stateLock.unlock()
        guard descriptor >= 0 else { return }
        while isRunning {
            let accepted = Darwin.accept(descriptor, nil, nil)
            if accepted >= 0 {
                setNoSigPipe(accepted)
                setTimeout(accepted, option: SO_RCVTIMEO, seconds: controlSocketTimeout)
                setTimeout(accepted, option: SO_SNDTIMEO, seconds: controlSocketTimeout)
                connectionQueue.async { [weak self] in self?.handleConnection(accepted) }
            } else if errno != EINTR && isRunning {
                break
            }
        }
    }

    private var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return running
    }

    private func handleConnection(_ descriptor: Int32) {
        var effectiveUID: uid_t = 0
        var effectiveGID: gid_t = 0
        guard getpeereid(descriptor, &effectiveUID, &effectiveGID) == 0,
              effectiveUID == getuid() else {
            close(descriptor)
            return
        }
        do {
            let data = try readLine(from: descriptor, maxBytes: controlMaxMessageBytes)
            let request = try JSONDecoder().decode(ControlRequest.self, from: data)
            DispatchQueue.main.async { [handler] in
                handler(request) { response in
                    self.connectionQueue.async {
                        self.send(response, on: descriptor)
                        close(descriptor)
                    }
                }
            }
        } catch let error as ControlTransportError {
            send(ControlResponse.failure(error.localizedDescription), on: descriptor)
            close(descriptor)
        } catch {
            send(ControlResponse.failure("Invalid request"), on: descriptor)
            close(descriptor)
        }
    }

    private func send(_ response: ControlResponse, on descriptor: Int32) {
        guard let data = try? controlJSONEncoder().encode(response) else { return }
        var framed = data
        framed.append(10)
        try? writeAll(framed, to: descriptor)
    }
}

public final class ControlClient {
    public let bundleIdentifier: String
    public let endpointPath: String
    public var connectTimeout: TimeInterval
    public var responseTimeout: TimeInterval

    public init(
        bundleIdentifier: String,
        connectTimeout: TimeInterval = 0.35,
        responseTimeout: TimeInterval = 5
    ) throws {
        self.bundleIdentifier = bundleIdentifier
        self.endpointPath = try ControlEndpoint.path(for: bundleIdentifier)
        self.connectTimeout = connectTimeout
        self.responseTimeout = responseTimeout
    }

    public init(
        endpointPath: String,
        connectTimeout: TimeInterval = 0.35,
        responseTimeout: TimeInterval = 5
    ) throws {
        guard endpointPath.utf8.count < 104 else { throw ControlTransportError.endpointPathTooLong }
        self.bundleIdentifier = ""
        self.endpointPath = endpointPath
        self.connectTimeout = connectTimeout
        self.responseTimeout = responseTimeout
    }

    /// Sends one request. A write or response timeout is never retried by
    /// this method, so callers cannot accidentally replay mutations.
    public func send(_ request: ControlRequest) throws -> ControlResponse {
        let encoded = try controlJSONEncoder().encode(request)
        guard encoded.count + 1 <= controlMaxMessageBytes else {
            throw ControlTransportError.requestTooLarge
        }
        guard try endpointExistsAsSafeSocket(endpointPath) else {
            throw ControlTransportError.connectFailed(ENOENT)
        }
        let descriptor = try createSocket()
        defer { close(descriptor) }
        try connect(descriptor)
        var effectiveUID: uid_t = 0
        var effectiveGID: gid_t = 0
        guard getpeereid(descriptor, &effectiveUID, &effectiveGID) == 0,
              effectiveUID == getuid() else {
            throw ControlTransportError.unsafeEndpoint
        }
        setTimeout(descriptor, option: SO_RCVTIMEO, seconds: responseTimeout)
        setTimeout(descriptor, option: SO_SNDTIMEO, seconds: responseTimeout)
        var framed = encoded
        framed.append(10)
        try writeAll(framed, to: descriptor)
        let responseData = try readLine(from: descriptor, maxBytes: controlMaxMessageBytes)
        guard !responseData.isEmpty else { throw ControlTransportError.invalidMessage }
        guard let response = try? JSONDecoder().decode(ControlResponse.self, from: responseData) else {
            throw ControlTransportError.invalidMessage
        }
        return response
    }

    private func connect(_ descriptor: Int32) throws {
        var address = try socketAddress(endpointPath).0
        setNonBlocking(descriptor, true)
        let result = withSockaddr(&address) { pointer, length in
            Darwin.connect(descriptor, pointer, length)
        }
        if result != 0, errno != EINPROGRESS {
            throw ControlTransportError.connectFailed(errno)
        }
        if result != 0 {
            guard waitFor(descriptor, events: Int16(POLLOUT), timeout: Int32(max(1, connectTimeout * 1000))) else {
                throw ControlTransportError.connectFailed(ETIMEDOUT)
            }
            var errorCode: Int32 = 0
            var errorLength = socklen_t(MemoryLayout<Int32>.size)
            guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &errorCode, &errorLength) == 0,
                  errorCode == 0 else {
                throw ControlTransportError.connectFailed(errorCode == 0 ? errno : errorCode)
            }
        }
        setNonBlocking(descriptor, false)
    }
}
