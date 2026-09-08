import Foundation
import CryptoKit

/// Values used by the small JSON protocol shared by `cpsm` and Capsomnia.
public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case bool(Bool)
    case number(Double)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value); return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value); return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

public struct ControlRequest: Codable, Equatable, Sendable {
    public let version: Int
    public let arguments: [String]

    public init(version: Int = 1, arguments: [String]) {
        self.version = version
        self.arguments = arguments
    }
}

public struct ControlResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let result: JSONValue?
    public let error: String?

    public init(ok: Bool, result: JSONValue? = nil, error: String? = nil) {
        self.ok = ok
        self.result = result
        self.error = error
    }

    public static func success(_ result: JSONValue? = nil) -> ControlResponse {
        ControlResponse(ok: true, result: result)
    }

    public static func failure(_ error: String) -> ControlResponse {
        ControlResponse(ok: false, error: error)
    }
}

public enum ControlTransportError: Error, Equatable, LocalizedError {
    case invalidBundleIdentifier
    case endpointPathTooLong
    case endpointUnavailable
    case endpointAlreadyRunning
    case unsafeEndpoint
    case socketCreationFailed(Int32)
    case connectFailed(Int32)
    case writeFailed(Int32)
    case requestTooLarge
    case responseTooLarge
    case readFailed(Int32)
    case timedOut
    case invalidMessage

    public var errorDescription: String? {
        switch self {
        case .invalidBundleIdentifier: return "Invalid app bundle identifier"
        case .endpointPathTooLong: return "Control endpoint path is too long"
        case .endpointUnavailable: return "Control endpoint is unavailable"
        case .endpointAlreadyRunning: return "Control server is already running"
        case .unsafeEndpoint: return "Control endpoint is not a safe user-owned socket"
        case let .socketCreationFailed(code): return "Could not create control socket (errno \(code))"
        case let .connectFailed(code): return "Could not connect to Capsomnia (errno \(code))"
        case let .writeFailed(code): return "Could not send request to Capsomnia (errno \(code))"
        case .requestTooLarge: return "Request is too large"
        case .responseTooLarge: return "Response is too large"
        case let .readFailed(code): return "Could not read Capsomnia response (errno \(code))"
        case .timedOut: return "Capsomnia did not respond in time"
        case .invalidMessage: return "Capsomnia returned an invalid response"
        }
    }
}

public enum ControlEndpoint {
    public static let defaultBundleIdentifier = "com.github.fuji-mak.capsomnia"

    /// The endpoint lives below a user-private cache directory. The name is
    /// deterministic so a CLI and the app can find one another without a
    /// network port or a launch-time rendezvous service.
    public static func path(for bundleIdentifier: String) throws -> String {
        guard !bundleIdentifier.isEmpty,
              !bundleIdentifier.contains("/"),
              !bundleIdentifier.contains("\0") else {
            throw ControlTransportError.invalidBundleIdentifier
        }
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = cache.appendingPathComponent("Capsomnia", isDirectory: true)
        let digest = SHA256.hash(data: Data(bundleIdentifier.utf8))
            .prefix(12).map { String(format: "%02x", $0) }.joined()
        let path = directory.appendingPathComponent("control-\(digest).sock").path
        if path.utf8.count >= 104 { throw ControlTransportError.endpointPathTooLong }
        return path
    }
}
