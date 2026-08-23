import Foundation

private enum PreferenceKey {
    static let dedicatedCapsLockMode = "DedicatedCapsLockMode"
    static let showMenuBarIcon = "ShowMenuBarIcon"
    static let language = "Language"
    static let launchAtLogin = "LaunchAtLogin"
    static let keepDisplayAwake = "KeepDisplayAwake"
    static let ignoreExternalCapsLockOffWhileLidClosed = "IgnoreExternalCapsLockOffWhileLidClosed"
    static let autoOffMinutes = "AutoOffMinutes"
    static let shortcutKeyCode = "ShortcutKeyCode"
    static let shortcutModifiers = "ShortcutModifiers"
    static let shortcutKey = "ShortcutKey"
    static let didCompleteInitialSetup = "DidCompleteInitialSetup"
    static let forceWelcomeOnNextLaunch = "ForceWelcomeOnNextLaunch"
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.dedicatedCapsLockMode: false,
            PreferenceKey.showMenuBarIcon: true,
            PreferenceKey.language: AppLanguage.defaultLanguage.rawValue,
            PreferenceKey.launchAtLogin: true,
            PreferenceKey.keepDisplayAwake: false,
            PreferenceKey.ignoreExternalCapsLockOffWhileLidClosed: false,
            PreferenceKey.autoOffMinutes: 0,
            PreferenceKey.didCompleteInitialSetup: false,
            PreferenceKey.forceWelcomeOnNextLaunch: false
        ])
    }

    static var dedicatedCapsLockMode: Bool {
        get { defaults.bool(forKey: PreferenceKey.dedicatedCapsLockMode) }
        set { defaults.set(newValue, forKey: PreferenceKey.dedicatedCapsLockMode) }
    }

    static var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: PreferenceKey.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: PreferenceKey.showMenuBarIcon) }
    }

    static var language: AppLanguage {
        get {
            AppLanguage(rawValue: defaults.string(forKey: PreferenceKey.language) ?? "")
                ?? AppLanguage.defaultLanguage
        }
        set { defaults.set(newValue.rawValue, forKey: PreferenceKey.language) }
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: PreferenceKey.launchAtLogin) }
        set { defaults.set(newValue, forKey: PreferenceKey.launchAtLogin) }
    }

    /// Keeps the display session awake while Capsomnia is on, including across
    /// the macOS idle timeout and lid closure.
    static var keepDisplayAwake: Bool {
        get { defaults.bool(forKey: PreferenceKey.keepDisplayAwake) }
        set { defaults.set(newValue, forKey: PreferenceKey.keepDisplayAwake) }
    }

    /// While the lid is closed the built-in keyboard cannot be pressed, so a
    /// Caps Lock turn-off observed in that window comes from an external
    /// source (e.g. a remote desktop client syncing its keyboard state to the
    /// host). When enabled, such turn-offs are ignored and Caps Lock is
    /// re-asserted instead of releasing sleep prevention. Turn-offs from the
    /// menu bar, the registered shortcut, and the auto-off timer stay
    /// effective.
    static var ignoreExternalCapsLockOffWhileLidClosed: Bool {
        get { defaults.bool(forKey: PreferenceKey.ignoreExternalCapsLockOffWhileLidClosed) }
        set { defaults.set(newValue, forKey: PreferenceKey.ignoreExternalCapsLockOffWhileLidClosed) }
    }

    /// Minutes after which awake mode turns itself off automatically.
    /// `0` means "no timer" — awake mode stays on until Caps Lock is turned off.
    /// Stored values are clamped to `0...AutoOffPreset.maxCustomMinutes`.
    static var autoOffMinutes: Int {
        get {
            let stored = defaults.integer(forKey: PreferenceKey.autoOffMinutes)
            return min(max(stored, 0), AutoOffPreset.maxCustomMinutes)
        }
        set {
            let clamped = min(max(newValue, 0), AutoOffPreset.maxCustomMinutes)
            defaults.set(clamped, forKey: PreferenceKey.autoOffMinutes)
        }
    }

    static var keyboardShortcut: KeyboardShortcut? {
        get {
            guard let keyCode = defaults.object(forKey: PreferenceKey.shortcutKeyCode) as? NSNumber,
                  let modifiers = defaults.object(forKey: PreferenceKey.shortcutModifiers) as? NSNumber,
                  let key = defaults.string(forKey: PreferenceKey.shortcutKey),
                  !key.isEmpty else {
                return nil
            }
            return KeyboardShortcut(
                keyCode: keyCode.uint32Value,
                modifiers: ShortcutModifiers(rawValue: modifiers.uint32Value),
                key: key
            )
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: PreferenceKey.shortcutKeyCode)
                defaults.removeObject(forKey: PreferenceKey.shortcutModifiers)
                defaults.removeObject(forKey: PreferenceKey.shortcutKey)
                return
            }
            defaults.set(newValue.keyCode, forKey: PreferenceKey.shortcutKeyCode)
            defaults.set(newValue.modifiers.rawValue, forKey: PreferenceKey.shortcutModifiers)
            defaults.set(newValue.key, forKey: PreferenceKey.shortcutKey)
        }
    }

    static var didCompleteInitialSetup: Bool {
        get { defaults.bool(forKey: PreferenceKey.didCompleteInitialSetup) }
        set { defaults.set(newValue, forKey: PreferenceKey.didCompleteInitialSetup) }
    }

    static func consumeForceWelcomeOnNextLaunch() -> Bool {
        let shouldShowWelcome = defaults.bool(forKey: PreferenceKey.forceWelcomeOnNextLaunch)
        if shouldShowWelcome {
            defaults.set(false, forKey: PreferenceKey.forceWelcomeOnNextLaunch)
        }
        return shouldShowWelcome
    }

}
