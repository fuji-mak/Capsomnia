import Foundation

struct IndicatorFeatureFlagStore {
    enum StoreError: LocalizedError {
        case invalidFeatureFlagsRoot
        case invalidIndicatorFlag
        case invalidBackup

        var errorDescription: String? {
            switch self {
            case .invalidFeatureFlagsRoot:
                return "the feature-flags property-list root is not a dictionary"
            case .invalidIndicatorFlag:
                return "redesigned_text_cursor is not a dictionary"
            case .invalidBackup:
                return "the Capsomnia indicator backup is invalid"
            }
        }
    }

    private struct Backup {
        let hadFeatureFlagsFile: Bool
        let hadIndicatorFlag: Bool
        let hadEnabledValue: Bool
        let enabledValue: Any?
    }

    private let featureFlagDirectoryURL: URL
    private let featureFlagURL: URL
    private let backupDirectoryURL: URL
    private let backupURL: URL
    private let fileManager: FileManager

    private let indicatorFlagKey = "redesigned_text_cursor"
    private let indicatorEnabledKey = "Enabled"

    init(
        featureFlagDirectoryURL: URL = URL(
            fileURLWithPath: "/Library/Preferences/FeatureFlags/Domain",
            isDirectory: true
        ),
        backupDirectoryURL: URL = URL(
            fileURLWithPath: "/Library/Application Support/Capsomnia",
            isDirectory: true
        ),
        fileManager: FileManager = .default
    ) {
        self.featureFlagDirectoryURL = featureFlagDirectoryURL
        featureFlagURL = featureFlagDirectoryURL.appendingPathComponent("UIKit.plist")
        self.backupDirectoryURL = backupDirectoryURL
        backupURL = backupDirectoryURL.appendingPathComponent("CapsLockIndicatorBackup.plist")
        self.fileManager = fileManager
    }

    /// Saves the original target value once, then applies Capsomnia's
    /// override while preserving every unrelated feature flag.
    func hide() throws {
        var flags = try readFeatureFlags() ?? [:]
        let originalIndicatorFlag = try readIndicatorFlag(from: flags)

        if try readBackup() == nil {
            try writeBackup(
                Backup(
                    hadFeatureFlagsFile: fileManager.fileExists(atPath: featureFlagURL.path),
                    hadIndicatorFlag: originalIndicatorFlag != nil,
                    hadEnabledValue: originalIndicatorFlag?[indicatorEnabledKey] != nil,
                    enabledValue: originalIndicatorFlag?[indicatorEnabledKey]
                )
            )
        }

        var indicatorFlag = originalIndicatorFlag ?? [:]
        indicatorFlag[indicatorEnabledKey] = false
        flags[indicatorFlagKey] = indicatorFlag
        try writeFeatureFlags(flags)
    }

    /// Handles an explicit toggle-off. When Capsomnia created the override,
    /// restore the saved value exactly; otherwise remove only the target
    /// override selected by the user.
    func show() throws {
        if let backup = try readBackup() {
            try restore(backup)
            try removeBackup()
            return
        }
        try removeOverrideWithoutBackup()
    }

    /// Used by the uninstaller. A missing backup means Capsomnia never took
    /// ownership, so an existing user-created override must remain untouched.
    func restoreIfManaged() throws {
        guard let backup = try readBackup() else {
            return
        }
        try restore(backup)
        try removeBackup()
    }

    private func readFeatureFlags() throws -> [String: Any]? {
        guard fileManager.fileExists(atPath: featureFlagURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: featureFlagURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let flags = plist as? [String: Any] else {
            throw StoreError.invalidFeatureFlagsRoot
        }
        return flags
    }

    private func readIndicatorFlag(from flags: [String: Any]) throws -> [String: Any]? {
        guard let value = flags[indicatorFlagKey] else {
            return nil
        }
        guard let indicatorFlag = value as? [String: Any] else {
            throw StoreError.invalidIndicatorFlag
        }
        return indicatorFlag
    }

    private func writeFeatureFlags(_ flags: [String: Any]) throws {
        try fileManager.createDirectory(
            at: featureFlagDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: flags,
            format: .xml,
            options: 0
        )
        try data.write(to: featureFlagURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: featureFlagURL.path
        )
    }

    private func writeBackup(_ backup: Backup) throws {
        try fileManager.createDirectory(
            at: backupDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        var plist: [String: Any] = [
            "Version": 1,
            "HadFeatureFlagsFile": backup.hadFeatureFlagsFile,
            "HadIndicatorFlag": backup.hadIndicatorFlag,
            "HadEnabledValue": backup.hadEnabledValue
        ]
        if let enabledValue = backup.enabledValue {
            plist["EnabledValue"] = enabledValue
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: backupURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: backupURL.path
        )
    }

    private func readBackup() throws -> Backup? {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: backupURL)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let plist = value as? [String: Any],
              let version = plist["Version"] as? Int,
              version == 1,
              let hadFeatureFlagsFile = plist["HadFeatureFlagsFile"] as? Bool,
              let hadIndicatorFlag = plist["HadIndicatorFlag"] as? Bool,
              let hadEnabledValue = plist["HadEnabledValue"] as? Bool else {
            throw StoreError.invalidBackup
        }

        guard hadIndicatorFlag || !hadEnabledValue else {
            throw StoreError.invalidBackup
        }
        let enabledValue = plist["EnabledValue"]
        guard hadEnabledValue == (enabledValue != nil) else {
            throw StoreError.invalidBackup
        }
        return Backup(
            hadFeatureFlagsFile: hadFeatureFlagsFile,
            hadIndicatorFlag: hadIndicatorFlag,
            hadEnabledValue: hadEnabledValue,
            enabledValue: enabledValue
        )
    }

    private func restore(_ backup: Backup) throws {
        var flags = try readFeatureFlags() ?? [:]

        if backup.hadIndicatorFlag {
            var indicatorFlag = try readIndicatorFlag(from: flags) ?? [:]
            if backup.hadEnabledValue, let enabledValue = backup.enabledValue {
                indicatorFlag[indicatorEnabledKey] = enabledValue
            } else {
                indicatorFlag.removeValue(forKey: indicatorEnabledKey)
            }
            flags[indicatorFlagKey] = indicatorFlag
        } else if var indicatorFlag = try readIndicatorFlag(from: flags) {
            indicatorFlag.removeValue(forKey: indicatorEnabledKey)
            if indicatorFlag.isEmpty {
                flags.removeValue(forKey: indicatorFlagKey)
            } else {
                flags[indicatorFlagKey] = indicatorFlag
            }
        }

        if flags.isEmpty && !backup.hadFeatureFlagsFile {
            try removeFeatureFlagFileIfPresent()
        } else {
            try writeFeatureFlags(flags)
        }
    }

    private func removeOverrideWithoutBackup() throws {
        guard var flags = try readFeatureFlags() else {
            return
        }
        _ = try readIndicatorFlag(from: flags)
        flags.removeValue(forKey: indicatorFlagKey)

        if flags.isEmpty {
            try removeFeatureFlagFileIfPresent()
        } else {
            try writeFeatureFlags(flags)
        }
    }

    private func removeFeatureFlagFileIfPresent() throws {
        guard fileManager.fileExists(atPath: featureFlagURL.path) else {
            return
        }
        try fileManager.removeItem(at: featureFlagURL)
    }

    private func removeBackup() throws {
        try fileManager.removeItem(at: backupURL)
        let remaining = try fileManager.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil
        )
        if remaining.isEmpty {
            try fileManager.removeItem(at: backupDirectoryURL)
        }
    }
}
