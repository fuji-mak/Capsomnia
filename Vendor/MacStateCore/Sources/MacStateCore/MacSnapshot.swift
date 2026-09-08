import Foundation

public struct MacSnapshot: Encodable {
    public let schemaVersion = 1
    public let capturedAt: String
    public let power: PowerSnapshot
    public let thermalState: String
    public let temperature: TemperatureSnapshot
    public let lidClosed: Bool?
    public let externalDisplayConnected: Bool?
    public let sleepDisabled: Bool?
    public let unavailable: [String: String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case capturedAt = "captured_at"
        case power, temperature, unavailable
        case thermalState = "thermal_state"
        case lidClosed = "lid_closed"
        case externalDisplayConnected = "external_display_connected"
        case sleepDisabled = "sleep_disabled"
    }

    public static func read() -> Self {
        let power = PowerStateReader.read()
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        let lid = ClamshellStateReader.isClosed()
        let display = ExternalDisplayReader.isConnected()
        let sleep = SleepStateReader.isDisabled()
        let temperature = TemperatureReader.read()
        var unavailable: [String: String] = [:]
        unavailable["temperature.cpu_celsius"] = "CPU temperature is not supported by MacReady 0.1."
        unavailable["temperature.gpu_celsius"] = "GPU temperature is not supported by MacReady 0.1."
        if temperature.batteryCelsius == nil {
            unavailable["temperature.battery_celsius"] = "Battery sensor is absent or returned an invalid value."
        }
        if power.source == "unknown" { unavailable["power.source"] = "Power source could not be read." }
        if power.batteryPresent == nil { unavailable["power.battery_present"] = "Battery presence could not be read." }
        if power.batteryPresent != false {
            if power.batteryPercent == nil { unavailable["power.battery_percent"] = "Battery capacity could not be read." }
            if power.charging == nil { unavailable["power.charging"] = "Charging state could not be read." }
        }
        if thermal == "unknown" { unavailable["thermal_state"] = "Unrecognized macOS thermal state." }
        if lid == nil { unavailable["lid_closed"] = "No lid state reported; the Mac may not have a lid." }
        if display == nil { unavailable["external_display_connected"] = "Display state could not be read in this session." }
        if sleep == nil { unavailable["sleep_disabled"] = "pmset did not report a valid SleepDisabled setting." }
        return Self(capturedAt: ISO8601DateFormatter().string(from: Date()), power: power, thermalState: thermal, temperature: temperature,
                    lidClosed: lid, externalDisplayConnected: display, sleepDisabled: sleep, unavailable: unavailable)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(capturedAt, forKey: .capturedAt)
        try values.encode(power, forKey: .power)
        try values.encode(thermalState, forKey: .thermalState)
        try values.encode(temperature, forKey: .temperature)
        try values.encode(lidClosed, forKey: .lidClosed)
        try values.encode(externalDisplayConnected, forKey: .externalDisplayConnected)
        try values.encode(sleepDisabled, forKey: .sleepDisabled)
        try values.encode(unavailable, forKey: .unavailable)
    }

    public func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    public var text: String {
        func flag(_ value: Bool?) -> String { value.map { $0 ? "yes" : "no" } ?? "unknown" }
        let battery = power.batteryPresent == false ? "not present" : power.batteryPercent.map { "\($0)%" } ?? "unknown"
        var lines = [
            "MacReady · \(capturedAt)",
            "Power: \(power.source)", "Battery: \(battery)", "Charging: \(flag(power.charging))",
            "Thermal state: \(thermalState)", "Lid closed: \(flag(lidClosed))",
            "External display connected: \(flag(externalDisplayConnected))",
            "System sleep disabled: \(flag(sleepDisabled))"
        ]
        lines.insert("Battery temperature: " + (temperature.batteryCelsius.map { "\($0) °C" } ?? "unknown"), at: 5)
        lines += unavailable.sorted { $0.key < $1.key }.map { "Unavailable: \($0.key) — \($0.value)" }
        return lines.joined(separator: "\n")
    }
}
