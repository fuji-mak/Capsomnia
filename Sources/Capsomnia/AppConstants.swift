import AppKit
import Foundation

let appName = "Capsomnia"
let appLabel = "com.github.fuji-mak.capsomnia"
let helperPath = "/Library/PrivilegedHelperTools/capsomnia-pmset"
let displaySleepHelperMode = "display-sleep"
let logDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/Capsomnia")
let logPath = logDirectoryURL
    .appendingPathComponent("capsomnia.log")
    .path
let openSettingsNotificationName = Notification.Name("\(appLabel).openSettings")
let brandLEDColor = NSColor(
    srgbRed: 184.0 / 255.0,
    green: 255.0 / 255.0,
    blue: 31.0 / 255.0,
    alpha: 1.0
)

/// Colors lifted straight from the landing page (docs/styles.css :root).
enum Brand {
    static func srgb(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    static let bg = srgb(0x000000)
    static let surface = srgb(0x0A0A0A)
    static let surface2 = srgb(0x111111)
    static let border = srgb(0x1F1F1F)
    static let borderStrong = srgb(0x2A2A2A)
    static let text = srgb(0xF2F4EC)
    static let textDim = srgb(0xA7AD9C)
    static let textFaint = srgb(0x6F7466)
    static let led = brandLEDColor
    static let ledBright = srgb(0xD8FF63)
    static let ledDeep = srgb(0x92F21D)
    static let offDot = srgb(0x2C2C2C)
    static let offDotBorder = srgb(0x3A3A3A)
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case japanese = "ja"

    static var defaultLanguage: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("ja") == true ? .japanese : .english
    }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .japanese:
            "日本語"
        }
    }
}

struct AppStrings {
    let showMenuBarIcon: String
    let showMenuBarIconDesc: String
    let language: String
    let openAtLogin: String
    let openAtLoginDesc: String
    let displaySleepOnLidClose: String
    let displaySleepOnLidCloseDesc: String
    let openCapsomnia: String
    let quit: String
    let settingsTitle: String
    let initialSettingsNote: String
    let welcomeTitle: String
    let explainerOnTitle: String
    let explainerOnDesc: String
    let explainerOffTitle: String
    let explainerOffDesc: String
    let permissionsHeading: String
    let inputMonitoringTitle: String
    let inputMonitoringDesc: String
    let openInputMonitoring: String
    let backgroundItemTitle: String
    let backgroundItemDesc: String
    let preferencesHeading: String
    let done: String
    let getStarted: String
    let tooltipOn: String
    let tooltipOff: String

    static func current() -> AppStrings {
        switch Preferences.language {
        case .english:
            AppStrings(
                showMenuBarIcon: "Show menu bar icon",
                showMenuBarIconDesc: "Display the LED status dot in the menu bar.",
                language: "Language",
                openAtLogin: "Open at login",
                openAtLoginDesc: "Launch Capsomnia automatically after you sign in.",
                displaySleepOnLidClose: "Turn display off when lid closes",
                displaySleepOnLidCloseDesc: "When Caps Lock is on, keep work running but let the display sleep after closing the lid.",
                openCapsomnia: "Open Capsomnia",
                quit: "Quit",
                settingsTitle: "Settings",
                initialSettingsNote: "Open Capsomnia again any time to change these.",
                welcomeTitle: "Welcome to Capsomnia",
                explainerOnTitle: "Caps Lock on",
                explainerOnDesc: "System sleep is disabled — work keeps running, lid open or closed.",
                explainerOffTitle: "Caps Lock off",
                explainerOffDesc: "Normal sleep behavior resumes.",
                permissionsHeading: "Permissions",
                inputMonitoringTitle: "Input Monitoring",
                inputMonitoringDesc: "Used only to detect Caps Lock changes immediately. Capsomnia does not read typed text, and it still works with a slower fallback if you skip this. If macOS asks, choose Quit & Reopen; this screen will return.",
                openInputMonitoring: "Open Input Monitoring",
                backgroundItemTitle: "Background Item",
                backgroundItemDesc: "macOS may show \"Taketo Fujimaki\" as a background item. It lets Capsomnia start at login and recover after crashes. Capsomnia has no network access or telemetry.",
                preferencesHeading: "Preferences",
                done: "Done",
                getStarted: "Get started",
                tooltipOn: "Caps Lock ON: processes stay awake",
                tooltipOff: "Caps Lock OFF: normal sleep"
            )
        case .japanese:
            AppStrings(
                showMenuBarIcon: "メニューバーに表示",
                showMenuBarIconDesc: "メニューバーにLEDステータスを表示します。",
                language: "言語",
                openAtLogin: "ログイン時に起動",
                openAtLoginDesc: "サインイン後にCapsomniaを自動で起動します。",
                displaySleepOnLidClose: "蓋を閉じたら画面をオフ",
                displaySleepOnLidCloseDesc: "Caps Lock ON中は作業を走らせたまま、蓋を閉じたら画面だけ暗くします。",
                openCapsomnia: "Capsomniaを開く",
                quit: "終了",
                settingsTitle: "設定",
                initialSettingsNote: "あとからCapsomniaを開けばいつでも変更できます。",
                welcomeTitle: "Capsomniaへようこそ",
                explainerOnTitle: "Caps Lock ON",
                explainerOnDesc: "システムスリープを無効化。蓋を閉じても作業が走り続けます。",
                explainerOffTitle: "Caps Lock OFF",
                explainerOffDesc: "通常のスリープ動作に戻ります。",
                permissionsHeading: "権限",
                inputMonitoringTitle: "入力監視",
                inputMonitoringDesc: "Caps Lockの切り替えをすぐ検知するためだけに使います。入力内容は読みません。許可しなくても少し遅れて動作します。macOSに「終了して再度開く」と表示されたら押してください。この画面に戻ります。",
                openInputMonitoring: "入力監視を開く",
                backgroundItemTitle: "バックグラウンド項目",
                backgroundItemDesc: "macOSが「Taketo Fujimakiのバックグラウンド項目」を表示することがあります。ログイン時の起動とクラッシュ時の復帰のためです。ネットワーク通信やテレメトリ収集は行いません。",
                preferencesHeading: "環境設定",
                done: "完了",
                getStarted: "はじめる",
                tooltipOn: "Caps Lock ON: スリープ抑止中",
                tooltipOff: "Caps Lock OFF: 通常のスリープ動作"
            )
        }
    }
}

private enum PreferenceKey {
    static let showMenuBarIcon = "ShowMenuBarIcon"
    static let language = "Language"
    static let launchAtLogin = "LaunchAtLogin"
    static let displaySleepOnLidClose = "DisplaySleepOnLidClose"
    static let didCompleteInitialSetup = "DidCompleteInitialSetup"
    static let forceWelcomeOnNextLaunch = "ForceWelcomeOnNextLaunch"
    static let inputMonitoringRequested = "InputMonitoringRequested"
    static let inputMonitoringReopenRequestedAt = "InputMonitoringReopenRequestedAt"
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.showMenuBarIcon: true,
            PreferenceKey.language: AppLanguage.defaultLanguage.rawValue,
            PreferenceKey.launchAtLogin: true,
            PreferenceKey.displaySleepOnLidClose: true,
            PreferenceKey.didCompleteInitialSetup: false,
            PreferenceKey.forceWelcomeOnNextLaunch: false
        ])
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

    static var displaySleepOnLidClose: Bool {
        get { defaults.bool(forKey: PreferenceKey.displaySleepOnLidClose) }
        set { defaults.set(newValue, forKey: PreferenceKey.displaySleepOnLidClose) }
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

    static func showWelcomeOnNextLaunch() {
        defaults.set(true, forKey: PreferenceKey.forceWelcomeOnNextLaunch)
    }

    static func markInputMonitoringReopenPending() {
        defaults.set(Date().timeIntervalSince1970, forKey: PreferenceKey.inputMonitoringReopenRequestedAt)
    }

    static func consumeFreshInputMonitoringReopenRequest(maxAge: TimeInterval = 600) -> Bool {
        let requestedAt = defaults.double(forKey: PreferenceKey.inputMonitoringReopenRequestedAt)
        guard requestedAt > 0 else { return false }

        defaults.removeObject(forKey: PreferenceKey.inputMonitoringReopenRequestedAt)
        return Date().timeIntervalSince1970 - requestedAt <= maxAge
    }

    static func migrateInputMonitoringPreferenceIfNeeded() {
        guard defaults.object(forKey: PreferenceKey.inputMonitoringRequested) == nil else { return }
        guard defaults.bool(forKey: PreferenceKey.didCompleteInitialSetup) else { return }
        defaults.set(true, forKey: PreferenceKey.inputMonitoringRequested)
    }

    static func ensureInputMonitoringChoiceRecorded() {
        guard defaults.object(forKey: PreferenceKey.inputMonitoringRequested) == nil else { return }
        defaults.set(false, forKey: PreferenceKey.inputMonitoringRequested)
    }

    static var inputMonitoringRequested: Bool {
        get { defaults.bool(forKey: PreferenceKey.inputMonitoringRequested) }
        set { defaults.set(newValue, forKey: PreferenceKey.inputMonitoringRequested) }
    }
}
