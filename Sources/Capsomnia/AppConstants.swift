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
    static let led = srgb(0xB8FF1F)
    static let ledBright = srgb(0xD8FF63)
    static let offDot = srgb(0x2C2C2C)
    static let offDotBorder = srgb(0x3A3A3A)
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"
    case korean = "ko"

    static var defaultLanguage: AppLanguage {
        defaultLanguage(for: Locale.preferredLanguages.first)
    }

    static func defaultLanguage(for preferredLanguage: String?) -> AppLanguage {
        let languageCode = preferredLanguage?
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first?
            .lowercased()

        if languageCode == "ja" {
            return .japanese
        }
        if languageCode == "zh" {
            return .simplifiedChinese
        }
        if languageCode == "ko" {
            return .korean
        }
        return .english
    }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .japanese:
            "日本語"
        case .simplifiedChinese:
            "简体中文"
        case .korean:
            "한국어"
        }
    }
}

struct AppStrings {
    let dedicatedCapsLockMode: String
    let dedicatedCapsLockModeDesc: String
    let toggleCapsLock: String
    let showMenuBarIcon: String
    let showMenuBarIconDesc: String
    let language: String
    let advancedSettings: String
    let advancedSettingsDesc: String
    let systemBehavior: String
    let openAtLogin: String
    let openAtLoginDesc: String
    let displaySleepOnLidClose: String
    let displaySleepOnLidCloseDesc: String
    let keyboardShortcut: String
    let keyboardShortcutDesc: String
    let shortcutRecorderPlaceholder: String
    let shortcutRecorderRecording: String
    let shortcutRecorderAction: String
    let shortcutRegistrationFailed: String
    let openCapsomnia: String
    let quit: String
    let settingsTitle: String
    let initialSettingsNote: String
    let welcomeTitle: String
    let explainerOnTitle: String
    let explainerOnDesc: String
    let explainerOffTitle: String
    let explainerOffDesc: String
    let initialPreferencesHeading: String
    let preferencesHeading: String
    let done: String
    let getStarted: String
    let tooltipOn: String
    let tooltipOff: String
    let tooltipError: String
    let tooltipDedicatedPermission: String

    static func current() -> AppStrings {
        localized(for: Preferences.language)
    }

    static func localized(for language: AppLanguage) -> AppStrings {
        switch language {
        case .english:
            AppStrings(
                dedicatedCapsLockMode: "Prevent all-caps typing",
                dedicatedCapsLockModeDesc: "When the indicator is on, Caps Lock no longer forces uppercase input. Shift still types uppercase letters. Requires Accessibility permission.",
                toggleCapsLock: "Toggle Caps Lock",
                showMenuBarIcon: "Show menu bar icon",
                showMenuBarIconDesc: "Display the LED status dot in the menu bar.",
                language: "Language",
                advancedSettings: "Advanced Settings",
                advancedSettingsDesc: "Sleep, login, and keyboard shortcut options",
                systemBehavior: "System Behavior",
                openAtLogin: "Open at login",
                openAtLoginDesc: "Launch Capsomnia automatically after you sign in.",
                displaySleepOnLidClose: "Turn display off when lid closes",
                displaySleepOnLidCloseDesc: "When Caps Lock is on, let the display sleep after closing the lid only if no external display is connected.",
                keyboardShortcut: "Toggle shortcut",
                keyboardShortcutDesc: "Use Command, Option, Control, or Shift with a function key to run the same Caps Lock toggle as the menu bar command.",
                shortcutRecorderPlaceholder: "Not Set",
                shortcutRecorderRecording: "Press keys…",
                shortcutRecorderAction: "Record",
                shortcutRegistrationFailed: "That shortcut is unavailable",
                openCapsomnia: "Open Capsomnia",
                quit: "Quit",
                settingsTitle: "Settings",
                initialSettingsNote: "Accessibility permission is required only when “Prevent all-caps typing” is enabled. macOS may display a background item named “Taketo Fujimaki”.",
                welcomeTitle: "Welcome to Capsomnia",
                explainerOnTitle: "Caps Lock on",
                explainerOnDesc: "System sleep is disabled — work keeps running, lid open or closed.",
                explainerOffTitle: "Caps Lock off",
                explainerOffDesc: "Normal sleep behavior resumes.",
                initialPreferencesHeading: "Initial setup",
                preferencesHeading: "Preferences",
                done: "Done",
                getStarted: "Get started",
                tooltipOn: "Caps Lock ON: processes stay awake",
                tooltipOff: "Caps Lock OFF: normal sleep",
                tooltipError: "Capsomnia could not update the sleep setting — retrying",
                tooltipDedicatedPermission: "“Prevent all-caps typing” requires Accessibility permission — sleep prevention is off"
            )
        case .korean:
            AppStrings(
                dedicatedCapsLockMode: "대문자 고정 방지",
                dedicatedCapsLockModeDesc: "표시등이 켜져 있어도 입력이 대문자로 고정되지 않도록 합니다. Shift를 누른 대문자 입력은 그대로 사용할 수 있습니다. 손쉬운 사용 권한이 필요합니다.",
                toggleCapsLock: "Caps Lock 전환",
                showMenuBarIcon: "메뉴 막대에 표시",
                showMenuBarIconDesc: "메뉴 막대에 LED 상태 표시를 보여 줍니다.",
                language: "언어",
                advancedSettings: "고급 설정",
                advancedSettingsDesc: "잠자기, 로그인 및 키보드 단축키 옵션",
                systemBehavior: "시스템 동작",
                openAtLogin: "로그인할 때 열기",
                openAtLoginDesc: "로그인하면 Capsomnia를 자동으로 실행합니다.",
                displaySleepOnLidClose: "덮개를 닫을 때 화면 끄기",
                displaySleepOnLidCloseDesc: "Caps Lock이 켜진 상태에서 덮개를 닫으면 외부 디스플레이가 연결되지 않은 경우에만 화면을 끕니다.",
                keyboardShortcut: "전환 단축키",
                keyboardShortcutDesc: "Command, Option, Control 또는 Shift와 기능 키를 함께 사용하여 메뉴 막대와 동일한 Caps Lock 전환을 실행합니다.",
                shortcutRecorderPlaceholder: "미설정",
                shortcutRecorderRecording: "입력 대기…",
                shortcutRecorderAction: "입력",
                shortcutRegistrationFailed: "사용할 수 없는 단축키입니다",
                openCapsomnia: "Capsomnia 열기",
                quit: "종료",
                settingsTitle: "설정",
                initialSettingsNote: "‘대문자 고정 방지’를 활성화하는 경우에만 손쉬운 사용 권한이 필요합니다. macOS에 ‘Taketo Fujimaki’ 백그라운드 항목이 표시될 수 있습니다.",
                welcomeTitle: "Capsomnia 시작하기",
                explainerOnTitle: "Caps Lock 켜기",
                explainerOnDesc: "시스템 잠자기를 막습니다. 덮개를 닫아도 작업은 계속됩니다.",
                explainerOffTitle: "Caps Lock 끄기",
                explainerOffDesc: "평소 잠자기 동작으로 돌아갑니다.",
                initialPreferencesHeading: "초기 설정",
                preferencesHeading: "기본 설정",
                done: "완료",
                getStarted: "시작하기",
                tooltipOn: "Caps Lock 켜짐: 잠자기 방지 중",
                tooltipOff: "Caps Lock 꺼짐: 평소 잠자기",
                tooltipError: "잠자기 설정을 바꾸지 못했습니다. 다시 시도 중입니다.",
                tooltipDedicatedPermission: "대문자 고정 방지 기능에는 손쉬운 사용 권한이 필요합니다. 잠자기 방지는 꺼져 있습니다."
            )
        case .japanese:
            AppStrings(
                dedicatedCapsLockMode: "大文字固定を防ぐ",
                dedicatedCapsLockModeDesc: "インジケーターがオンの時に入力が大文字固定になるのを無効化します。Shiftでの大文字入力は維持します。アクセシビリティ権限が必要です。",
                toggleCapsLock: "Caps Lockを切り替え",
                showMenuBarIcon: "メニューバーに表示",
                showMenuBarIconDesc: "メニューバーにLEDステータスを表示します。",
                language: "言語",
                advancedSettings: "詳細設定",
                advancedSettingsDesc: "画面・ログイン・ショートカットの設定",
                systemBehavior: "システム動作",
                openAtLogin: "ログイン時に起動",
                openAtLoginDesc: "サインイン後にCapsomniaを自動で起動します。",
                displaySleepOnLidClose: "蓋を閉じたら画面をオフ",
                displaySleepOnLidCloseDesc: "Caps Lock ON中は、外部ディスプレイが接続されていない場合のみ、蓋を閉じたら画面を暗くします。",
                keyboardShortcut: "切り替えショートカット",
                keyboardShortcutDesc: "Command、Option、Controlのいずれか、またはShift＋ファンクションキーで、メニューバーと同じCaps Lock切り替えを実行します。",
                shortcutRecorderPlaceholder: "未設定",
                shortcutRecorderRecording: "入力待ち…",
                shortcutRecorderAction: "入力する",
                shortcutRegistrationFailed: "そのショートカットは使用できません",
                openCapsomnia: "Capsomniaを開く",
                quit: "終了",
                settingsTitle: "設定",
                initialSettingsNote: "「大文字固定を防ぐ」を有効にする場合のみ、アクセシビリティ権限が必要です。macOSに「Taketo Fujimakiのバックグラウンド項目」と表示される場合があります。",
                welcomeTitle: "Capsomniaへようこそ",
                explainerOnTitle: "Caps Lock ON",
                explainerOnDesc: "システムスリープを無効化。蓋を閉じても作業が走り続けます。",
                explainerOffTitle: "Caps Lock OFF",
                explainerOffDesc: "通常のスリープ動作に戻ります。",
                initialPreferencesHeading: "初期設定",
                preferencesHeading: "環境設定",
                done: "完了",
                getStarted: "はじめる",
                tooltipOn: "Caps Lock ON: スリープ抑止中",
                tooltipOff: "Caps Lock OFF: 通常のスリープ動作",
                tooltipError: "スリープ設定を更新できませんでした — 再試行中",
                tooltipDedicatedPermission: "「大文字固定を防ぐ」にはアクセシビリティ権限が必要です — スリープ抑止OFF"
            )
        case .simplifiedChinese:
            AppStrings(
                dedicatedCapsLockMode: "防止输入锁定为大写",
                dedicatedCapsLockModeDesc: "指示灯亮起时，防止输入被锁定为大写。仍可按住 Shift 输入大写字母。需要辅助功能权限。",
                toggleCapsLock: "切换 Caps Lock",
                showMenuBarIcon: "显示菜单栏图标",
                showMenuBarIconDesc: "在菜单栏中显示 LED 状态指示灯。",
                language: "语言",
                advancedSettings: "高级设置",
                advancedSettingsDesc: "显示屏、登录和键盘快捷键选项",
                systemBehavior: "系统行为",
                openAtLogin: "登录时启动",
                openAtLoginDesc: "登录后自动启动 Capsomnia。",
                displaySleepOnLidClose: "合盖时关闭显示屏",
                displaySleepOnLidCloseDesc: "Caps Lock 开启时，仅在未连接外接显示器的情况下，合盖后让显示屏进入睡眠。",
                keyboardShortcut: "切换快捷键",
                keyboardShortcutDesc: "使用包含 Command、Option、Control，或 Shift 与功能键的快捷键，执行与菜单栏相同的 Caps Lock 切换。",
                shortcutRecorderPlaceholder: "未设置",
                shortcutRecorderRecording: "等待输入…",
                shortcutRecorderAction: "录入",
                shortcutRegistrationFailed: "该快捷键不可用",
                openCapsomnia: "打开 Capsomnia",
                quit: "退出",
                settingsTitle: "设置",
                initialSettingsNote: "仅在启用“防止输入锁定为大写”时才需要辅助功能权限。macOS 可能会显示名为“Taketo Fujimaki”的后台项目。",
                welcomeTitle: "欢迎使用 Capsomnia",
                explainerOnTitle: "Caps Lock 已开启",
                explainerOnDesc: "系统睡眠已停用——无论开盖还是合盖，任务都会继续运行。",
                explainerOffTitle: "Caps Lock 已关闭",
                explainerOffDesc: "已恢复正常睡眠。",
                initialPreferencesHeading: "初始设置",
                preferencesHeading: "偏好设置",
                done: "完成",
                getStarted: "开始使用",
                tooltipOn: "Caps Lock 已开启：任务将保持运行",
                tooltipOff: "Caps Lock 已关闭：正常睡眠",
                tooltipError: "Capsomnia 无法更新睡眠设置——正在重试",
                tooltipDedicatedPermission: "“防止输入锁定为大写”需要辅助功能权限——睡眠防止已关闭"
            )
        }
    }
}

private enum PreferenceKey {
    static let dedicatedCapsLockMode = "DedicatedCapsLockMode"
    static let showMenuBarIcon = "ShowMenuBarIcon"
    static let language = "Language"
    static let launchAtLogin = "LaunchAtLogin"
    static let displaySleepOnLidClose = "DisplaySleepOnLidClose"
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
            PreferenceKey.displaySleepOnLidClose: true,
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

    static var displaySleepOnLidClose: Bool {
        get { defaults.bool(forKey: PreferenceKey.displaySleepOnLidClose) }
        set { defaults.set(newValue, forKey: PreferenceKey.displaySleepOnLidClose) }
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
