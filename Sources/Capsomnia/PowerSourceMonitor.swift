import Foundation
import IOKit.ps

enum PowerSource: String, Equatable {
    case ac
    case battery
    case unknown
}

enum PowerSourcePolicy {
    static func effectiveState(requested: Bool, source: PowerSource, disableOnBattery: Bool) -> Bool {
        requested && !(disableOnBattery && source == .battery)
    }

    static func isLocked(source: PowerSource, disableOnBattery: Bool) -> Bool {
        disableOnBattery && source == .battery
    }
}

final class PowerSourceMonitor {
    func currentSource() -> PowerSource {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unknown
        }
        for item in list {
            guard let details = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                  let state = details[kIOPSPowerSourceStateKey] as? String else { continue }
            if state == kIOPSACPowerValue { return .ac }
            if state == kIOPSBatteryPowerValue { return .battery }
        }
        return .unknown
    }
}
