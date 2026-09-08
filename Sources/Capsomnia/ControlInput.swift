import Foundation

enum ControlInput {
    static func boolean(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "on", "true": return true
        case "off", "false": return false
        default: return nil
        }
    }

    static func duration(_ text: String) -> TimeInterval? {
        guard let unit = text.last, let amount = Double(text.dropLast()), amount.isFinite else { return nil }
        let multiplier: Double
        switch unit {
        case "s": multiplier = 1
        case "m": multiplier = 60
        case "h": multiplier = 3600
        default: return nil
        }
        let seconds = amount * multiplier
        return (1...86400).contains(seconds) ? seconds : nil
    }
}
