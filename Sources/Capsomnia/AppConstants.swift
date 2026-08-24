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
    let systemBehavior: String
    let openAtLogin: String
    let openAtLoginDesc: String
    let keepDisplayAwake: String
    let keepDisplayAwakeDesc: String
    let ignoreExternalCapsLockOffWhileLidClosed: String
    let ignoreExternalCapsLockOffWhileLidClosedDesc: String
    let autoOffTimer: String
    let autoOffTimerDesc: String
    let autoOffOff: String
    let autoOffCustom: String
    let autoOffTurnsOffIn: String
    let autoOffHours: String
    let autoOffMinutesUnit: String
    let autoOffRestart: String
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
    let checkForUpdates: String
    let updateAvailableMenuFormat: String
    let updateAvailableTitle: String
    let updateAvailableBodyFormat: String
    let updateDownloadAndInstall: String
    let updateLater: String
    let updateUpToDateTitle: String
    let updateUpToDateBodyFormat: String
    let updateCheckFailedTitle: String
    let updateCheckFailedBody: String
    let automaticUpdateChecks: String
    let automaticUpdateChecksDesc: String

    static func current() -> AppStrings {
        localized(for: Preferences.language)
    }

    static func localized(for language: AppLanguage) -> AppStrings {
        switch language {
        case .english:
            AppStrings(
                dedicatedCapsLockMode: "Prevent all-caps typing",
                dedicatedCapsLockModeDesc: "When Capsomnia is on, Caps Lock no longer forces uppercase input. Shift still types uppercase letters. Requires Accessibility permission.",
                toggleCapsLock: "Toggle Caps Lock",
                showMenuBarIcon: "Show menu bar icon",
                showMenuBarIconDesc: "Display the LED status dot in the menu bar.",
                language: "Language",
                advancedSettings: "Advanced Settings",
                systemBehavior: "System Behavior",
                openAtLogin: "Open at login",
                openAtLoginDesc: "Launch Capsomnia automatically after you sign in.",
                keepDisplayAwake: "Keep display awake",
                keepDisplayAwakeDesc: "Keeps the display awake while Capsomnia is on. Useful when using Computer Use or similar tools.",
                ignoreExternalCapsLockOffWhileLidClosed: "Ignore Caps Lock turn-offs while the lid is closed",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "While the lid is closed, sleep prevention stays on even if Caps Lock is turned off — for example by a remote desktop client syncing its keyboard state. The menu bar, the toggle shortcut, and the auto-off timer still turn it off.",
                autoOffTimer: "Auto-off timer",
                autoOffTimerDesc: "After the set time, Capsomnia turns awake mode off and puts your Mac to sleep.",
                autoOffOff: "Off",
                autoOffCustom: "Custom",
                autoOffTurnsOffIn: "Turns off in",
                autoOffHours: "Hours",
                autoOffMinutesUnit: "Minutes",
                autoOffRestart: "Restart timer",
                keyboardShortcut: "Toggle shortcut",
                keyboardShortcutDesc: "If you’ve assigned Caps Lock to another key, you can use a shortcut to turn Capsomnia on and off. While Capsomnia is on, the green Caps Lock light stays lit.",
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
                tooltipDedicatedPermission: "“Prevent all-caps typing” requires Accessibility permission — sleep prevention is off",
                checkForUpdates: "Check for Updates…",
                updateAvailableMenuFormat: "Update available — %@",
                updateAvailableTitle: "Update available",
                updateAvailableBodyFormat: "Capsomnia %@ is available — you have %@. Download the installer and open it? The download is removed automatically after the update.",
                updateDownloadAndInstall: "Download & Install",
                updateLater: "Later",
                updateUpToDateTitle: "You’re up to date",
                updateUpToDateBodyFormat: "Capsomnia %@ is the latest version.",
                updateCheckFailedTitle: "Update check failed",
                updateCheckFailedBody: "Couldn’t reach GitHub to check for updates. Try again later.",
                automaticUpdateChecks: "Check for updates automatically",
                automaticUpdateChecksDesc: "Checks GitHub's public release information once a day and shows new versions in the menu bar menu. Capsomnia sends no telemetry, identifiers, or personal data."
            )
        case .korean:
            AppStrings(
                dedicatedCapsLockMode: "대문자 고정 방지",
                dedicatedCapsLockModeDesc: "Capsomnia가 켜져 있을 때 입력이 대문자로 고정되지 않도록 합니다. Shift를 누른 대문자 입력은 그대로 사용할 수 있습니다. 손쉬운 사용 권한이 필요합니다.",
                toggleCapsLock: "Caps Lock 전환",
                showMenuBarIcon: "메뉴 막대에 표시",
                showMenuBarIconDesc: "메뉴 막대에 LED 상태 표시를 보여 줍니다.",
                language: "언어",
                advancedSettings: "고급 설정",
                systemBehavior: "시스템 동작",
                openAtLogin: "로그인할 때 열기",
                openAtLoginDesc: "로그인하면 Capsomnia를 자동으로 실행합니다.",
                keepDisplayAwake: "화면 켜진 상태로 유지",
                keepDisplayAwakeDesc: "Capsomnia가 켜져 있는 동안 화면이 잠자기 상태로 전환되지 않도록 합니다. Computer Use 등을 사용할 때 유용합니다.",
                ignoreExternalCapsLockOffWhileLidClosed: "덮개를 닫은 동안 Caps Lock에 의한 끄기 무시",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "덮개가 닫혀 있는 동안에는 Caps Lock이 꺼져도 잠자기 방지를 유지합니다. 원격 데스크톱 연결 등으로 의도치 않게 해제되는 것을 방지합니다. 메뉴 막대, 전환 단축키, 자동 종료 타이머로는 평소대로 끌 수 있습니다.",
                autoOffTimer: "자동 종료 타이머",
                autoOffTimerDesc: "설정한 시간이 지나면 절전 방지를 끄고 Mac을 잠자기 상태로 전환합니다.",
                autoOffOff: "끄기",
                autoOffCustom: "사용자 지정",
                autoOffTurnsOffIn: "종료까지",
                autoOffHours: "시간",
                autoOffMinutesUnit: "분",
                autoOffRestart: "타이머 재시작",
                keyboardShortcut: "전환 단축키",
                keyboardShortcutDesc: "Caps Lock을 다른 키에 할당한 경우에도 원하는 단축키로 Capsomnia를 켜거나 끌 수 있습니다. Capsomnia가 켜져 있는 동안에는 초록색 Caps Lock 표시등이 켜집니다.",
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
                tooltipDedicatedPermission: "대문자 고정 방지 기능에는 손쉬운 사용 권한이 필요합니다. 잠자기 방지는 꺼져 있습니다.",
                checkForUpdates: "업데이트 확인…",
                updateAvailableMenuFormat: "업데이트 있음 — %@",
                updateAvailableTitle: "업데이트가 있습니다",
                updateAvailableBodyFormat: "Capsomnia %@ 버전을 사용할 수 있습니다. 현재 버전은 %@입니다. 설치 프로그램을 다운로드해서 열까요? 다운로드한 파일은 업데이트 후 자동으로 제거됩니다.",
                updateDownloadAndInstall: "다운로드 및 설치",
                updateLater: "나중에",
                updateUpToDateTitle: "최신 버전입니다",
                updateUpToDateBodyFormat: "Capsomnia %@이(가) 최신 버전입니다.",
                updateCheckFailedTitle: "업데이트 확인 실패",
                updateCheckFailedBody: "GitHub에 연결해 업데이트를 확인하지 못했습니다. 나중에 다시 시도해 주세요.",
                automaticUpdateChecks: "자동으로 업데이트 확인",
                automaticUpdateChecksDesc: "하루에 한 번 GitHub의 공개 릴리스 정보를 확인하고 새 버전을 메뉴 막대 메뉴에 표시합니다. Capsomnia는 텔레메트리, 식별자, 개인 정보를 전송하지 않습니다."
            )
        case .japanese:
            AppStrings(
                dedicatedCapsLockMode: "大文字固定を防ぐ",
                dedicatedCapsLockModeDesc: "Capsomniaがオンのときに、入力が大文字になるのを無効化します。Shiftでの大文字入力は維持します。アクセシビリティ権限が必要です。",
                toggleCapsLock: "Caps Lockを切り替え",
                showMenuBarIcon: "メニューバーに表示",
                showMenuBarIconDesc: "メニューバーにLEDステータスを表示します。",
                language: "言語",
                advancedSettings: "詳細設定",
                systemBehavior: "システム動作",
                openAtLogin: "ログイン時に起動",
                openAtLoginDesc: "サインイン後にCapsomniaを自動で起動します。",
                keepDisplayAwake: "画面をスリープさせない",
                keepDisplayAwakeDesc: "Capsomniaがオンの時に画面をスリープしないようにします。Computer Useなどを使う際に有効です。",
                ignoreExternalCapsLockOffWhileLidClosed: "蓋を閉じている間はCaps Lockによるオフを無視",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "蓋を閉じている間は、Caps Lockがオフになってもスリープ抑止を維持します。リモートデスクトップ接続などで意図せず解除されるのを防ぎます。メニューバー・切り替えショートカット・自動オフタイマーからは通常どおりオフにできます。",
                autoOffTimer: "自動オフタイマー",
                autoOffTimerDesc: "設定した時間が経過すると、スリープ抑止を解除してMacをスリープさせます。",
                autoOffOff: "オフ",
                autoOffCustom: "カスタム",
                autoOffTurnsOffIn: "オフまで",
                autoOffHours: "時間",
                autoOffMinutesUnit: "分",
                autoOffRestart: "タイマーを再スタート",
                keyboardShortcut: "切り替えショートカット",
                keyboardShortcutDesc: "Caps Lockを別のキーに割り当てている場合でも、お好みのショートカットでCapsomniaをオン／オフできます。Capsomniaがオンの間は、Caps Lockの緑のライトが点灯します。",
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
                tooltipDedicatedPermission: "「大文字固定を防ぐ」にはアクセシビリティ権限が必要です — スリープ抑止OFF",
                checkForUpdates: "アップデートを確認…",
                updateAvailableMenuFormat: "アップデートあり — %@",
                updateAvailableTitle: "アップデートがあります",
                updateAvailableBodyFormat: "Capsomnia %@ が利用できます（現在は %@）。インストーラをダウンロードして開きますか？ダウンロードしたファイルはアップデート後に自動で削除されます。",
                updateDownloadAndInstall: "ダウンロードしてインストール",
                updateLater: "あとで",
                updateUpToDateTitle: "最新の状態です",
                updateUpToDateBodyFormat: "Capsomnia %@ は最新バージョンです。",
                updateCheckFailedTitle: "アップデートを確認できませんでした",
                updateCheckFailedBody: "GitHubに接続してアップデートを確認できませんでした。あとでもう一度お試しください。",
                automaticUpdateChecks: "アップデートを自動で確認",
                automaticUpdateChecksDesc: "1日に1回GitHubの公開リリース情報を確認し、新しいバージョンをメニューバーのメニューに表示します。Capsomniaがテレメトリや識別子、個人情報を送信することはありません。"
            )
        case .simplifiedChinese:
            AppStrings(
                dedicatedCapsLockMode: "防止输入锁定为大写",
                dedicatedCapsLockModeDesc: "Capsomnia 开启时，防止输入被锁定为大写。仍可按住 Shift 输入大写字母。需要辅助功能权限。",
                toggleCapsLock: "切换 Caps Lock",
                showMenuBarIcon: "显示菜单栏图标",
                showMenuBarIconDesc: "在菜单栏中显示 LED 状态指示灯。",
                language: "语言",
                advancedSettings: "高级设置",
                systemBehavior: "系统行为",
                openAtLogin: "登录时启动",
                openAtLoginDesc: "登录后自动启动 Capsomnia。",
                keepDisplayAwake: "保持显示屏常亮",
                keepDisplayAwakeDesc: "Capsomnia 开启时防止显示屏进入睡眠。使用 Computer Use 等工具时很有用。",
                ignoreExternalCapsLockOffWhileLidClosed: "合盖期间忽略 Caps Lock 的关闭操作",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "合盖期间，即使 Caps Lock 被关闭也会保持防睡眠，防止远程桌面连接等意外解除防睡眠。菜单栏、切换快捷键和自动关闭定时器仍可正常关闭。",
                autoOffTimer: "自动关闭定时器",
                autoOffTimerDesc: "设定时间结束后会关闭防睡眠并让 Mac 进入睡眠。",
                autoOffOff: "关闭",
                autoOffCustom: "自定义",
                autoOffTurnsOffIn: "剩余",
                autoOffHours: "小时",
                autoOffMinutesUnit: "分钟",
                autoOffRestart: "重启计时器",
                keyboardShortcut: "切换快捷键",
                keyboardShortcutDesc: "即使已将 Caps Lock 分配给其他按键，也可以使用自定义快捷键开启或关闭 Capsomnia。Capsomnia 开启期间，绿色 Caps Lock 指示灯会保持亮起。",
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
                tooltipDedicatedPermission: "“防止输入锁定为大写”需要辅助功能权限——睡眠防止已关闭",
                checkForUpdates: "检查更新…",
                updateAvailableMenuFormat: "有可用更新 — %@",
                updateAvailableTitle: "有可用更新",
                updateAvailableBodyFormat: "Capsomnia %@ 已发布，当前版本为 %@。要下载并打开安装器吗？更新完成后会自动移除下载的文件。",
                updateDownloadAndInstall: "下载并安装",
                updateLater: "稍后",
                updateUpToDateTitle: "已是最新版本",
                updateUpToDateBodyFormat: "Capsomnia %@ 已是最新版本。",
                updateCheckFailedTitle: "检查更新失败",
                updateCheckFailedBody: "无法连接 GitHub 检查更新。请稍后再试。",
                automaticUpdateChecks: "自动检查更新",
                automaticUpdateChecksDesc: "每天检查一次 GitHub 的公开发布信息，并在菜单栏菜单中显示新版本。Capsomnia 不会发送遥测数据、标识符或个人信息。"
            )
        }
    }
}
