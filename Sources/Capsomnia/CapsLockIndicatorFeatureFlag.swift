import Foundation

/// Reads whether the macOS Caps Lock indicator that appears in text fields is
/// suppressed through the `redesigned_text_cursor` UIKit feature-flag
/// override. The override is written by the privileged helper; the file is
/// world-readable, so state can be checked without elevation.
enum CapsLockIndicatorFeatureFlag {
    static let plistPath = "/Library/Preferences/FeatureFlags/Domain/UIKit.plist"
    static let flagKey = "redesigned_text_cursor"
    static let enabledKey = "Enabled"

    static func isHidden() -> Bool {
        isHidden(plistData: try? Data(contentsOf: URL(fileURLWithPath: plistPath)))
    }

    static func isHidden(plistData: Data?) -> Bool {
        guard let plistData,
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData,
                  format: nil
              ) as? [String: Any],
              let flag = plist[flagKey] as? [String: Any],
              let enabled = flag[enabledKey] as? Bool else {
            return false
        }
        return !enabled
    }
}

struct CapsLockIndicatorBootSnapshot: Equatable {
    var bootTime: TimeInterval
    var hiddenAtBoot: Bool
}

struct CapsLockIndicatorDisplayState: Equatable {
    var hidden: Bool
    var restartPending: Bool
}

/// Decides whether a restart is still needed for an indicator change to take
/// effect, by comparing the on-disk flag against a snapshot of its value when
/// the current boot was first observed.
enum CapsLockIndicatorRestartPolicy {
    /// kern.boottime can shift by a few seconds when the system clock is
    /// adjusted; readings closer than this are the same boot.
    static let sameBootTolerance: TimeInterval = 60

    static func evaluate(
        snapshot: CapsLockIndicatorBootSnapshot?,
        currentBootTime: TimeInterval?,
        currentHidden: Bool
    ) -> (snapshot: CapsLockIndicatorBootSnapshot?, restartPending: Bool) {
        guard let currentBootTime else {
            // Without a boot time, keep whatever snapshot exists and compare
            // against it; a stale snapshot beats losing a pending warning.
            guard let snapshot else {
                return (nil, false)
            }
            return (snapshot, snapshot.hiddenAtBoot != currentHidden)
        }

        guard let snapshot,
              abs(snapshot.bootTime - currentBootTime) <= sameBootTolerance else {
            let refreshed = CapsLockIndicatorBootSnapshot(
                bootTime: currentBootTime,
                hiddenAtBoot: currentHidden
            )
            return (refreshed, false)
        }

        return (snapshot, snapshot.hiddenAtBoot != currentHidden)
    }
}
