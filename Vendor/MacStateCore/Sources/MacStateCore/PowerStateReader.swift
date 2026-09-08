import Foundation
import IOKit.ps

public struct PowerSnapshot: Encodable {
    public let source: String
    public let batteryPresent: Bool?
    public let batteryPercent: Double?
    public let charging: Bool?

    enum CodingKeys: String, CodingKey {
        case source, charging
        case batteryPresent = "battery_present"
        case batteryPercent = "battery_percent"
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(source, forKey: .source)
        try values.encode(batteryPresent, forKey: .batteryPresent)
        try values.encode(batteryPercent, forKey: .batteryPercent)
        try values.encode(charging, forKey: .charging)
    }
}

public enum PowerStateReader {
    public static func read() -> PowerSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerSnapshot(source: "unknown", batteryPresent: nil, batteryPercent: nil, charging: nil)
        }
        let provider = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let descriptions = sources.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        guard descriptions.count == sources.count else {
            return PowerSnapshot(source: "unknown", batteryPresent: nil, batteryPercent: nil, charging: nil)
        }
        return parse(source: provider, descriptions: descriptions)
    }

    static func parse(source: String?, descriptions: [[String: Any]]) -> PowerSnapshot {
        let sourceName: String
        switch source {
        case kIOPMACPowerKey: sourceName = "ac"
        case kIOPMBatteryPowerKey: sourceName = "battery"
        case kIOPMUPSPowerKey: sourceName = "ups"
        default: sourceName = "unknown"
        }
        guard let battery = descriptions.first(where: {
            $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }) else {
            return PowerSnapshot(source: sourceName, batteryPresent: false, batteryPercent: nil, charging: nil)
        }
        let present = battery[kIOPSIsPresentKey] as? Bool
        let current = (battery[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue
        let maximum = (battery[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue
        let percent: Double?
        if present != false, let current, let maximum,
           current.isFinite, maximum.isFinite, maximum > 0, current >= 0, current <= maximum {
            percent = (current / maximum * 1000).rounded() / 10
        } else { percent = nil }
        return PowerSnapshot(source: sourceName, batteryPresent: present, batteryPercent: percent,
                             charging: present == false ? nil : battery[kIOPSIsChargingKey] as? Bool)
    }
}
