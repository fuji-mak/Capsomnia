import Foundation

/// Pure decision logic for the built-in update check. Networking, alerts, and
/// file handling live in `UpdateController`.
enum InstallerCleanupAction: Equatable {
    case none
    case keepWaiting
    case offerRemoval(path: String, version: String)
    case clearRecord
}

enum UpdateCheck {
    /// Whether an automatic (non-user-initiated) check is due. A last-check
    /// date in the future means the clock moved backwards; check again rather
    /// than blocking until the recorded date is reached.
    static func shouldAutoCheck(now: Date, lastCheckedAt: Date?, minimumInterval: TimeInterval) -> Bool {
        guard let lastCheckedAt else {
            return true
        }
        if lastCheckedAt > now {
            return true
        }
        return now.timeIntervalSince(lastCheckedAt) >= minimumInterval
    }

    /// What to do with a previously downloaded installer package. The download
    /// is offered for removal only after the app is running as (at least) the
    /// version that installer delivered.
    static func installerCleanupAction(
        currentVersion: String,
        recordedPath: String?,
        recordedVersion: String?,
        fileExists: (String) -> Bool
    ) -> InstallerCleanupAction {
        guard let recordedPath, let recordedVersion else {
            return .none
        }
        guard fileExists(recordedPath) else {
            return .clearRecord
        }
        if isVersion(recordedVersion, newerThan: currentVersion) {
            return .keepWaiting
        }
        return .offerRemoval(path: recordedPath, version: recordedVersion)
    }

    /// Compares two dotted numeric versions ("3.4.0"). Missing components are
    /// treated as zero, so "3.4" equals "3.4.0". Returns `false` whenever
    /// either version contains a non-numeric component.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        guard let candidateComponents = numericComponents(of: candidate),
              let currentComponents = numericComponents(of: current) else {
            return false
        }
        let count = max(candidateComponents.count, currentComponents.count)
        for index in 0..<count {
            let lhs = index < candidateComponents.count ? candidateComponents[index] : 0
            let rhs = index < currentComponents.count ? currentComponents[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }

    /// Release tags are published as "v3.5.0"; the bundle version is "3.5.0".
    static func version(fromTag tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Extracts the release version from a GitHub "latest release" API payload.
    static func parseLatestReleaseVersion(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let release = object as? [String: Any],
              let tag = release["tag_name"] as? String else {
            return nil
        }
        return version(fromTag: tag)
    }

    private static func numericComponents(of version: String) -> [Int]? {
        guard !version.isEmpty else {
            return nil
        }
        var components: [Int] = []
        for part in version.split(separator: ".", omittingEmptySubsequences: false) {
            guard let value = Int(part), value >= 0 else {
                return nil
            }
            components.append(value)
        }
        return components
    }
}
