import CoreGraphics

enum ExternalDisplayReader {
    static func isConnected() -> Bool? {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else {
            return nil
        }

        guard displayCount > 0 else { return false }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else {
            return nil
        }

        return displays.prefix(Int(displayCount)).contains { CGDisplayIsBuiltin($0) == 0 }
    }
}
