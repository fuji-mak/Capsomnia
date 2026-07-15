import AppKit
import Foundation

let appName = "Capsomnia"
let appLabel = "com.github.fuji-mak.capsomnia"
let helperPath = "/Library/PrivilegedHelperTools/capsomnia-pmset"
let displaySleepHelperMode = "display-sleep"
let systemSleepHelperMode = "sleep-now"
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
    let autoSleepAfterAgentTask: String
    let cancelPendingAutoSleep: (Int) -> String
    let quit: String
    let tooltipOn: String
    let tooltipOff: String
    let tooltipDisabled: String
    let tooltipError: String
    let menuError: String

    static func current() -> AppStrings {
        switch Preferences.language {
        case .simplifiedChinese:
            AppStrings(
                enabled: "合盖时保持开机状态",
                openAtLogin: "开机自动启动 Capsomnia",
                displaySleepOnLidClose: "合盖自动关闭外接显示器",
                autoSleepAfterAgentTask: "Codex/Claude任务完成后自动睡眠",
                cancelPendingAutoSleep: { seconds in "取消本次自动睡眠（\(seconds)秒）" },
                quit: "退出 Capsomnia",
                tooltipOn: "当前状态：持续运行",
                tooltipOff: "当前状态：正常休眠",
                tooltipDisabled: "当前状态：已停用（正常休眠）",
                tooltipError: "当前状态：设置失败，正在重试",
                menuError: "设置失败，正在自动重试"
            )
        case .english:
            AppStrings(
                enabled: "Keep Mac Awake When Lid Closes",
                openAtLogin: "Start Capsomnia at Login",
                displaySleepOnLidClose: "Turn External Displays Off When Lid Closes",
                autoSleepAfterAgentTask: "Sleep After Codex/Claude Tasks Finish",
                cancelPendingAutoSleep: { seconds in "Cancel This Sleep (\(seconds)s)" },
                quit: "Quit Capsomnia",
                tooltipOn: "Current status: keep running",
                tooltipOff: "Current status: normal sleep",
                tooltipDisabled: "Current status: disabled (normal sleep)",
                tooltipError: "Capsomnia could not update the sleep setting — retrying",
                menuError: "Setting failed. Retrying automatically"
            )
        case .japanese:
            AppStrings(
                enabled: "蓋を閉じてもMacをスリープさせない",
                openAtLogin: "ログイン時に Capsomnia を起動",
                displaySleepOnLidClose: "蓋を閉じたら外部ディスプレイをオフ",
                autoSleepAfterAgentTask: "Codex/Claudeのタスク完了後に自動スリープ",
                cancelPendingAutoSleep: { seconds in "今回の自動スリープをキャンセル（\(seconds)秒）" },
                quit: "Capsomniaを終了",
                tooltipOn: "現在の状態：作業継続中",
                tooltipOff: "現在の状態：通常のスリープ動作",
                tooltipDisabled: "現在の状態：無効（通常のスリープ動作）",
                tooltipError: "スリープ設定を更新できませんでした — 再試行中",
                menuError: "設定に失敗しました。自動で再試行しています"
            )
        }
    }
}

private enum PreferenceKey {
    static let enabled = "Enabled"
    static let language = "Language"
    static let launchAtLogin = "LaunchAtLogin"
    static let displaySleepOnLidClose = "DisplaySleepOnLidClose"
    static let autoSleepAfterAgentTask = "AutoSleepAfterAgentTask"
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.enabled: false,
            PreferenceKey.language: AppLanguage.defaultLanguage.rawValue,
            PreferenceKey.launchAtLogin: true,
            PreferenceKey.displaySleepOnLidClose: true,
            PreferenceKey.autoSleepAfterAgentTask: true
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

    static var autoSleepAfterAgentTask: Bool {
        get { defaults.bool(forKey: PreferenceKey.autoSleepAfterAgentTask) }
        set { defaults.set(newValue, forKey: PreferenceKey.autoSleepAfterAgentTask) }
    }

}
