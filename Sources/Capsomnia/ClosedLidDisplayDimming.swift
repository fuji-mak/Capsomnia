import CoreGraphics
import Darwin
import Foundation

enum ClosedLidDisplayDimmingPolicy {
    static func shouldDim(
        keepDisplayAwake: Bool,
        capsLockOn: Bool,
        sleepPreventionConfirmed: Bool,
        displayAwakeAssertionActive: Bool,
        clamshellClosed: Bool?
    ) -> Bool {
        keepDisplayAwake
            && capsLockOn
            && sleepPreventionConfirmed
            && displayAwakeAssertionActive
            && clamshellClosed == true
    }
}

/// Temporarily lowers only the built-in display to minimum brightness and
/// restores the exact value that was present before dimming.
final class ClosedLidDisplayDimmingController {
    private let readBrightness: () -> Float?
    private let writeBrightness: (Float) -> Bool
    private var savedBrightness: Float?

    convenience init() {
        let brightness = DisplayServicesBrightness()
        self.init(
            readBrightness: { brightness.read() },
            writeBrightness: { brightness.write($0) }
        )
    }

    init(
        readBrightness: @escaping () -> Float?,
        writeBrightness: @escaping (Float) -> Bool
    ) {
        self.readBrightness = readBrightness
        self.writeBrightness = writeBrightness
    }

    var isDimmed: Bool {
        savedBrightness != nil
    }

    /// Idempotently dims or restores the display. A failed restore retains the
    /// saved value so the caller can retry without losing it.
    @discardableResult
    func setDimmed(_ dimmed: Bool) -> Bool {
        if dimmed {
            guard savedBrightness == nil else { return true }
            guard let brightness = readBrightness() else { return false }
            guard writeBrightness(0) else { return false }
            savedBrightness = min(max(brightness, 0), 1)
            return true
        }

        guard let brightness = savedBrightness else { return true }
        guard writeBrightness(brightness) else { return false }
        savedBrightness = nil
        return true
    }
}

/// Loads DisplayServices at runtime so builds remain independent of private
/// framework headers. The display ID is selected through public CoreGraphics
/// APIs and is always restricted to the Mac's built-in panel.
private final class DisplayServicesBrightness {
    private typealias GetBrightness = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let frameworkHandle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?
    private var cachedDisplayID: CGDirectDisplayID?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        frameworkHandle = dlopen(path, RTLD_LAZY | RTLD_LOCAL)

        if let frameworkHandle,
           let symbol = dlsym(frameworkHandle, "DisplayServicesGetBrightness") {
            getBrightness = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            getBrightness = nil
        }

        if let frameworkHandle,
           let symbol = dlsym(frameworkHandle, "DisplayServicesSetBrightness") {
            setBrightness = unsafeBitCast(symbol, to: SetBrightness.self)
        } else {
            setBrightness = nil
        }
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func read() -> Float? {
        guard let getBrightness,
              let displayID = builtInDisplayID() else {
            return nil
        }

        cachedDisplayID = displayID
        var brightness: Float = 0
        guard getBrightness(displayID, &brightness) == 0,
              brightness.isFinite else {
            return nil
        }
        return brightness
    }

    func write(_ brightness: Float) -> Bool {
        guard let setBrightness,
              let displayID = cachedDisplayID ?? builtInDisplayID() else {
            return false
        }
        return setBrightness(displayID, min(max(brightness, 0), 1)) == 0
    }

    private func builtInDisplayID() -> CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count) == .success else {
            return nil
        }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
