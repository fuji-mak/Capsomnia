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
let openMenuNotificationName = Notification.Name("\(appLabel).openMenu")
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
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    static var defaultLanguage: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferredLanguage.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if preferredLanguage.hasPrefix("ja") {
            return .japanese
        }
        return .english
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese:
            "简体中文"
        case .english:
            "English"
        case .japanese:
            "日本語"
        }
    }
}

struct AppStrings {
    let enabled: String
    let openAtLogin: String
    let displaySleepOnLidClose: String
    let quit: String
    let tooltipOn: String
    let tooltipOff: String
    let tooltipDisabled: String
    let tooltipError: String

    static func current() -> AppStrings {
        switch Preferences.language {
        case .simplifiedChinese:
            AppStrings(
                enabled: "启用",
                openAtLogin: "登录后自动启动",
                displaySleepOnLidClose: "合盖时关闭显示器",
                quit: "退出 Capsomnia",
                tooltipOn: "当前状态：持续运行",
                tooltipOff: "当前状态：正常休眠",
                tooltipDisabled: "当前状态：已停用（正常休眠）",
                tooltipError: "当前状态：设置失败，正在重试"
            )
        case .english:
            AppStrings(
                enabled: "Enabled",
                openAtLogin: "Open at login",
                displaySleepOnLidClose: "Turn display off when lid closes",
                quit: "Quit Capsomnia",
                tooltipOn: "Current status: keep running",
                tooltipOff: "Current status: normal sleep",
                tooltipDisabled: "Current status: disabled (normal sleep)",
                tooltipError: "Capsomnia could not update the sleep setting — retrying"
            )
        case .japanese:
            AppStrings(
                enabled: "有効",
                openAtLogin: "ログイン時に起動",
                displaySleepOnLidClose: "蓋を閉じたら画面をオフ",
                quit: "Capsomniaを終了",
                tooltipOn: "現在の状態：作業継続中",
                tooltipOff: "現在の状態：通常のスリープ動作",
                tooltipDisabled: "現在の状態：無効（通常のスリープ動作）",
                tooltipError: "スリープ設定を更新できませんでした — 再試行中"
            )
        }
    }
}

private enum PreferenceKey {
    static let enabled = "Enabled"
    static let language = "Language"
    static let launchAtLogin = "LaunchAtLogin"
    static let displaySleepOnLidClose = "DisplaySleepOnLidClose"
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.enabled: false,
            PreferenceKey.language: AppLanguage.defaultLanguage.rawValue,
            PreferenceKey.launchAtLogin: true,
            PreferenceKey.displaySleepOnLidClose: true
        ])
    }

    static var enabled: Bool {
        get { defaults.bool(forKey: PreferenceKey.enabled) }
        set { defaults.set(newValue, forKey: PreferenceKey.enabled) }
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

}
