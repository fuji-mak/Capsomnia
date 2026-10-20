import AppKit
import Foundation

let appName = "Capsomnia"
let appLabel = Bundle.main.bundleIdentifier ?? "com.github.fuji-mak.capsomnia"
/// Developer ID team that signs Capsomnia's release packages
/// (scripts/build-pkg.sh). Downloaded update installers must be signed by
/// this team before they are opened.
let developerTeamID = "ZJZ8627852"
let helperPath = "/Library/PrivilegedHelperTools/capsomnia-pmset"
let displaySleepHelperMode = "display-sleep"
let indicatorHideHelperMode = "indicator-hide"
let indicatorShowHelperMode = "indicator-show"
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
    let keepHotspotAlive: String
    let keepHotspotAliveDesc: String
    let ignoreExternalCapsLockOffWhileLidClosed: String
    let ignoreExternalCapsLockOffWhileLidClosedDesc: String
    let hideCapsLockIndicator: String
    let hideCapsLockIndicatorDesc: String
    let hideCapsLockIndicatorRestartNote: String
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
    let updateAction: String
    let updateAvailableVersionFormat: String
    let updateDownloadAndInstall: String
    let updateLater: String
    let updateUpToDateTitle: String
    let updateUpToDateBodyFormat: String
    let updateCheckFailedTitle: String
    let updateCheckFailedBody: String
    let updateDownloadFailedTitle: String
    let updateDownloadFailedBody: String
    let releaseNotes: String
    let updatesHeading: String
    let updateCurrentVersionFormat: String
    let automaticUpdateChecks: String
    let automaticUpdateChecksDesc: String

    static func current() -> AppStrings {
        localized(for: Preferences.language)
    }

    static func localized(for language: AppLanguage) -> AppStrings {
        switch language {
        case .english:
            AppStrings(
                dedicatedCapsLockMode: "Prevent capitalization",
                dedicatedCapsLockModeDesc: "Prevents input from becoming uppercase while Capsomnia is on. Requires Accessibility permission.",
                toggleCapsLock: "Toggle Caps Lock",
                showMenuBarIcon: "Show menu bar icon",
                showMenuBarIconDesc: "Display the LED status dot in the menu bar.",
                language: "Language",
                advancedSettings: "Advanced Settings",
                systemBehavior: "System Behavior",
                openAtLogin: "Open at login",
                openAtLoginDesc: "Launch Capsomnia automatically after you sign in.",
                keepDisplayAwake: "Use Computer Use and similar tools",
                keepDisplayAwakeDesc: "Prevents screen locking while Capsomnia is on for tasks that use the screen. Power consumption and device temperature may increase.",
                keepHotspotAlive: "Keep hotspot connected",
                keepHotspotAliveDesc: "Prevents the hotspot connection from disconnecting automatically when idle.",
                ignoreExternalCapsLockOffWhileLidClosed: "Prevent turn-offs from Caps Lock sync",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "While the lid is closed, sleep prevention continues even if a remote connection or similar source turns Caps Lock off.",
                hideCapsLockIndicator: "Hide the Caps Lock indicator",
                hideCapsLockIndicatorDesc: "Hide the Caps Lock indicator shown in text fields.",
                hideCapsLockIndicatorRestartNote: "Restart your Mac to apply this change.",
                autoOffTimer: "Auto-off timer",
                autoOffTimerDesc: "After the set time, Capsomnia stops preventing sleep.",
                autoOffOff: "Off",
                autoOffCustom: "Custom",
                autoOffTurnsOffIn: "Turns off in",
                autoOffHours: "Hours",
                autoOffMinutesUnit: "Minutes",
                autoOffRestart: "Restart timer",
                keyboardShortcut: "Toggle shortcut",
                keyboardShortcutDesc: "If you’ve assigned Caps Lock to another key, you can use a shortcut to turn Capsomnia on and off.",
                shortcutRecorderPlaceholder: "Not Set",
                shortcutRecorderRecording: "Press keys…",
                shortcutRecorderAction: "Record",
                shortcutRegistrationFailed: "That shortcut is unavailable",
                openCapsomnia: "Open Capsomnia",
                quit: "Quit",
                settingsTitle: "Settings",
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
                tooltipDedicatedPermission: "“Prevent capitalization” is unavailable — retrying. Check Accessibility permission.",
                checkForUpdates: "Check for Updates…",
                updateAvailableMenuFormat: "Update available — %@",
                updateAvailableTitle: "Update available",
                updateAvailableBodyFormat: "Capsomnia %@ is available — you have %@. Download the installer and open it? The download is removed automatically after the update.",
                updateAction: "Update",
                updateAvailableVersionFormat: "%@ available",
                updateDownloadAndInstall: "Download & Install",
                updateLater: "Later",
                updateUpToDateTitle: "You’re up to date",
                updateUpToDateBodyFormat: "Capsomnia %@ is the latest version.",
                updateCheckFailedTitle: "Update check failed",
                updateCheckFailedBody: "Couldn’t reach GitHub to check for updates. Try again later.",
                updateDownloadFailedTitle: "Update failed",
                updateDownloadFailedBody: "The installer couldn’t be downloaded or opened. Try again later, or download it from the GitHub releases page.",
                releaseNotes: "Info",
                updatesHeading: "Updates",
                updateCurrentVersionFormat: "Current version: %@",
                automaticUpdateChecks: "Check for updates automatically",
                automaticUpdateChecksDesc: "Checks for releases once a day."
            )
        case .korean:
            AppStrings(
                dedicatedCapsLockMode: "대문자 변환 방지",
                dedicatedCapsLockModeDesc: "Capsomnia가 켜져 있을 때 입력이 대문자로 변환되는 것을 방지합니다. 손쉬운 사용 권한이 필요합니다.",
                toggleCapsLock: "Caps Lock 전환",
                showMenuBarIcon: "메뉴 막대에 표시",
                showMenuBarIconDesc: "메뉴 막대에 LED 상태 표시를 보여 줍니다.",
                language: "언어",
                advancedSettings: "고급 설정",
                systemBehavior: "시스템 동작",
                openAtLogin: "로그인할 때 열기",
                openAtLoginDesc: "로그인하면 Capsomnia를 자동으로 실행합니다.",
                keepDisplayAwake: "Computer Use 등 사용",
                keepDisplayAwakeDesc: "화면을 사용하는 작업을 위해 Capsomnia가 켜져 있는 동안 화면 잠금을 방지합니다. 전력 소비와 기기 온도가 증가할 수 있습니다.",
                keepHotspotAlive: "핫스팟 연결 유지",
                keepHotspotAliveDesc: "핫스팟 연결이 유휴 상태에서 자동으로 끊어지지 않도록 합니다.",
                ignoreExternalCapsLockOffWhileLidClosed: "Caps Lock 동기화로 인한 꺼짐 방지",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "덮개를 닫은 동안 원격 연결 등으로 Caps Lock이 꺼져도 잠자기 방지를 유지합니다.",
                hideCapsLockIndicator: "Caps Lock 표시기 숨기기",
                hideCapsLockIndicatorDesc: "텍스트 입력란에 표시되는 Caps Lock 표시기를 숨깁니다.",
                hideCapsLockIndicatorRestartNote: "변경 사항을 적용하려면 Mac을 재시동하세요.",
                autoOffTimer: "자동 종료 타이머",
                autoOffTimerDesc: "설정한 시간이 지나면 절전 방지를 해제합니다.",
                autoOffOff: "끄기",
                autoOffCustom: "사용자 지정",
                autoOffTurnsOffIn: "종료까지",
                autoOffHours: "시간",
                autoOffMinutesUnit: "분",
                autoOffRestart: "타이머 재시작",
                keyboardShortcut: "전환 단축키",
                keyboardShortcutDesc: "Caps Lock을 다른 키에 할당한 경우에도 원하는 단축키로 Capsomnia를 켜거나 끌 수 있습니다.",
                shortcutRecorderPlaceholder: "미설정",
                shortcutRecorderRecording: "입력 대기…",
                shortcutRecorderAction: "입력",
                shortcutRegistrationFailed: "사용할 수 없는 단축키입니다",
                openCapsomnia: "Capsomnia 열기",
                quit: "종료",
                settingsTitle: "설정",
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
                tooltipDedicatedPermission: "대문자 변환 방지 기능을 사용할 수 없어 다시 시도 중입니다. 손쉬운 사용 권한을 확인하세요.",
                checkForUpdates: "업데이트 확인…",
                updateAvailableMenuFormat: "업데이트 있음 — %@",
                updateAvailableTitle: "업데이트가 있습니다",
                updateAvailableBodyFormat: "Capsomnia %@ 버전을 사용할 수 있습니다. 현재 버전은 %@입니다. 설치 프로그램을 다운로드해서 열까요? 다운로드한 파일은 업데이트 후 자동으로 제거됩니다.",
                updateAction: "업데이트",
                updateAvailableVersionFormat: "%@ 사용 가능",
                updateDownloadAndInstall: "다운로드 및 설치",
                updateLater: "나중에",
                updateUpToDateTitle: "최신 버전입니다",
                updateUpToDateBodyFormat: "Capsomnia %@이(가) 최신 버전입니다.",
                updateCheckFailedTitle: "업데이트 확인 실패",
                updateCheckFailedBody: "GitHub에 연결해 업데이트를 확인하지 못했습니다. 나중에 다시 시도해 주세요.",
                updateDownloadFailedTitle: "업데이트 실패",
                updateDownloadFailedBody: "설치 프로그램을 다운로드하거나 열지 못했습니다. 나중에 다시 시도하거나 GitHub 릴리스 페이지에서 다운로드해 주세요.",
                releaseNotes: "정보",
                updatesHeading: "업데이트",
                updateCurrentVersionFormat: "현재 버전: %@",
                automaticUpdateChecks: "자동으로 업데이트 확인",
                automaticUpdateChecksDesc: "하루에 한 번 릴리스 상태를 확인합니다."
            )
        case .japanese:
            AppStrings(
                dedicatedCapsLockMode: "大文字化を防ぐ",
                dedicatedCapsLockModeDesc: "Capsomniaがオンの時に入力が大文字になるのを防ぎます。アクセシビリティ権限が必要です。",
                toggleCapsLock: "Caps Lockを切り替え",
                showMenuBarIcon: "メニューバーに表示",
                showMenuBarIconDesc: "メニューバーにLEDステータスを表示します。",
                language: "言語",
                advancedSettings: "詳細設定",
                systemBehavior: "システム動作",
                openAtLogin: "ログイン時に起動",
                openAtLoginDesc: "サインイン後にCapsomniaを自動で起動します。",
                keepDisplayAwake: "Computer Use等を使う",
                keepDisplayAwakeDesc: "画面を使う処理のために、Capsomniaがオンの時は画面ロックを防ぎます。消費電力や本体温度が上昇する可能性があります。",
                keepHotspotAlive: "テザリング時に接続を維持",
                keepHotspotAliveDesc: "テザリングがアイドル時に自動切断されないようにします",
                ignoreExternalCapsLockOffWhileLidClosed: "Caps Lockの同期によるオフを防ぐ",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "蓋を閉じている間、リモート接続などでCaps Lockがオフになってもスリープ抑止を続けます。",
                hideCapsLockIndicator: "Caps Lockインジケータを非表示",
                hideCapsLockIndicatorDesc: "テキスト入力欄に表示されるCaps Lockインジケータを非表示にします。",
                hideCapsLockIndicatorRestartNote: "変更を反映するにはMacを再起動してください。",
                autoOffTimer: "自動オフタイマー",
                autoOffTimerDesc: "設定した時間が経過すると、スリープ抑止を解除します。",
                autoOffOff: "オフ",
                autoOffCustom: "カスタム",
                autoOffTurnsOffIn: "オフまで",
                autoOffHours: "時間",
                autoOffMinutesUnit: "分",
                autoOffRestart: "タイマーを再スタート",
                keyboardShortcut: "切り替えショートカット",
                keyboardShortcutDesc: "Caps Lockを別のキーに割り当てている場合でも、お好みのショートカットでCapsomniaをオン／オフできます。",
                shortcutRecorderPlaceholder: "未設定",
                shortcutRecorderRecording: "入力待ち…",
                shortcutRecorderAction: "入力する",
                shortcutRegistrationFailed: "そのショートカットは使用できません",
                openCapsomnia: "Capsomniaを開く",
                quit: "終了",
                settingsTitle: "設定",
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
                tooltipDedicatedPermission: "「大文字化を防ぐ」が動作していません — 再試行中。アクセシビリティ権限を確認してください。",
                checkForUpdates: "アップデートを確認…",
                updateAvailableMenuFormat: "アップデートあり — %@",
                updateAvailableTitle: "アップデートがあります",
                updateAvailableBodyFormat: "Capsomnia %@ が利用できます（現在は %@）。インストーラをダウンロードして開きますか？ダウンロードしたファイルはアップデート後に自動で削除されます。",
                updateAction: "更新",
                updateAvailableVersionFormat: "%@が利用可能",
                updateDownloadAndInstall: "ダウンロードしてインストール",
                updateLater: "あとで",
                updateUpToDateTitle: "最新の状態です",
                updateUpToDateBodyFormat: "Capsomnia %@ は最新バージョンです。",
                updateCheckFailedTitle: "アップデートを確認できませんでした",
                updateCheckFailedBody: "GitHubに接続してアップデートを確認できませんでした。あとでもう一度お試しください。",
                updateDownloadFailedTitle: "アップデートに失敗しました",
                updateDownloadFailedBody: "インストーラをダウンロードまたは開くことができませんでした。あとでもう一度試すか、GitHubのリリースページからダウンロードしてください。",
                releaseNotes: "情報",
                updatesHeading: "アップデート",
                updateCurrentVersionFormat: "現在のバージョン：%@",
                automaticUpdateChecks: "アップデートを自動で確認",
                automaticUpdateChecksDesc: "1日1回リリース状況を確認します。"
            )
        case .simplifiedChinese:
            AppStrings(
                dedicatedCapsLockMode: "防止大写转换",
                dedicatedCapsLockModeDesc: "Capsomnia 开启时，防止输入变为大写。需要辅助功能权限。",
                toggleCapsLock: "切换 Caps Lock",
                showMenuBarIcon: "显示菜单栏图标",
                showMenuBarIconDesc: "在菜单栏中显示 LED 状态指示灯。",
                language: "语言",
                advancedSettings: "高级设置",
                systemBehavior: "系统行为",
                openAtLogin: "登录时启动",
                openAtLoginDesc: "登录后自动启动 Capsomnia。",
                keepDisplayAwake: "使用 Computer Use 等工具",
                keepDisplayAwakeDesc: "为支持需要使用屏幕的任务，Capsomnia 开启时会防止屏幕锁定。功耗和机身温度可能会上升。",
                keepHotspotAlive: "保持热点连接",
                keepHotspotAliveDesc: "防止热点连接在空闲时自动断开。",
                ignoreExternalCapsLockOffWhileLidClosed: "防止 Caps Lock 同步导致关闭",
                ignoreExternalCapsLockOffWhileLidClosedDesc: "合盖时，即使远程连接等导致 Caps Lock 关闭，也会继续防止睡眠。",
                hideCapsLockIndicator: "隐藏大写锁定指示器",
                hideCapsLockIndicatorDesc: "隐藏文本输入框中显示的 Caps Lock 指示器。",
                hideCapsLockIndicatorRestartNote: "重新启动 Mac 后此更改才会生效。",
                autoOffTimer: "自动关闭定时器",
                autoOffTimerDesc: "设定时间结束后，将关闭防睡眠功能。",
                autoOffOff: "关闭",
                autoOffCustom: "自定义",
                autoOffTurnsOffIn: "剩余",
                autoOffHours: "小时",
                autoOffMinutesUnit: "分钟",
                autoOffRestart: "重启计时器",
                keyboardShortcut: "切换快捷键",
                keyboardShortcutDesc: "即使已将 Caps Lock 分配给其他按键，也可以使用自定义快捷键开启或关闭 Capsomnia。",
                shortcutRecorderPlaceholder: "未设置",
                shortcutRecorderRecording: "等待输入…",
                shortcutRecorderAction: "录入",
                shortcutRegistrationFailed: "该快捷键不可用",
                openCapsomnia: "打开 Capsomnia",
                quit: "退出",
                settingsTitle: "设置",
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
                tooltipDedicatedPermission: "“防止大写转换”暂不可用，正在重试。请检查辅助功能权限。",
                checkForUpdates: "检查更新…",
                updateAvailableMenuFormat: "有可用更新 — %@",
                updateAvailableTitle: "有可用更新",
                updateAvailableBodyFormat: "Capsomnia %@ 已发布，当前版本为 %@。要下载并打开安装器吗？更新完成后会自动移除下载的文件。",
                updateAction: "更新",
                updateAvailableVersionFormat: "%@ 可用",
                updateDownloadAndInstall: "下载并安装",
                updateLater: "稍后",
                updateUpToDateTitle: "已是最新版本",
                updateUpToDateBodyFormat: "Capsomnia %@ 已是最新版本。",
                updateCheckFailedTitle: "检查更新失败",
                updateCheckFailedBody: "无法连接 GitHub 检查更新。请稍后再试。",
                updateDownloadFailedTitle: "更新失败",
                updateDownloadFailedBody: "无法下载或打开安装器。请稍后再试，或从 GitHub 发布页面下载。",
                releaseNotes: "详情",
                updatesHeading: "更新",
                updateCurrentVersionFormat: "当前版本：%@",
                automaticUpdateChecks: "自动检查更新",
                automaticUpdateChecksDesc: "每天检查一次发布状态。"
            )
        }
    }
}

struct HotspotStrings {
    let language: AppLanguage
    static func current() -> HotspotStrings { localized(for: Preferences.language) }
    static func localized(for language: AppLanguage) -> HotspotStrings { HotspotStrings(language: language) }
    private func text(_ en: String, _ ko: String, _ ja: String, _ zh: String) -> String {
        switch language {
        case .english: return en
        case .korean: return ko
        case .japanese: return ja
        case .simplifiedChinese: return zh
        }
    }
    var title: String { text("Auto-connect to hotspot", "핫스팟 자동 연결", "ホットスポットに自動接続", "自动连接热点") }
    var description: String { text("While Capsomnia is on, reconnect after Wi-Fi is lost for 5 seconds. The hotspot must already be broadcasting.", "Capsomnia가 켜져 있을 때 Wi-Fi가 5초간 끊기면 다시 연결합니다. 핫스팟이 이미 켜져 있어야 합니다.", "Capsomniaがオンの間、Wi-Fi切断が5秒続くと再接続します。ホットスポットが発信中である必要があります。", "Capsomnia 开启时，Wi-Fi 断开 5 秒后重新连接。热点必须已开启并广播。") }
    var ssid: String { text("Hotspot Wi-Fi name (SSID)", "핫스팟 Wi-Fi 이름 (SSID)", "ホットスポットのWi-Fi名 (SSID)", "热点 Wi-Fi 名称 (SSID)") }
    var password: String { text("Password (saved only in Keychain)", "암호 (키체인에만 저장)", "パスワード (キーチェーンのみに保存)", "密码（仅存于钥匙串）") }
    var save: String { text("Save password", "암호 저장", "パスワードを保存", "保存密码") }
    var forget: String { text("Forget password", "암호 삭제", "パスワードを削除", "忘记密码") }
    var requestLocation: String { text("Allow Location access", "위치 접근 허용", "位置情報を許可", "允许位置访问") }
    var locationSettings: String { text("Location Settings", "위치 설정", "位置情報設定", "位置设置") }
    var wifiSettings: String { text("Open Wi-Fi Settings", "Wi-Fi 설정 열기", "Wi-Fi設定を開く", "打开 Wi-Fi 设置") }
    var instantHotspot: String { text("To wake a nearby iPhone hotspot, use macOS 26 or later: Wi-Fi Settings > Ask to join hotspots > Automatic. Use the same Apple Account or Family Sharing, with Wi-Fi and Bluetooth on. This system setting also works when Capsomnia is off; no hotspot password is needed.", "근처 iPhone 핫스팟을 켜려면 macOS 26 이상에서 Wi-Fi 설정 > 핫스팟 연결 요청 > 자동을 선택하세요. 동일한 Apple 계정 또는 가족 공유를 사용하고 Wi-Fi와 Bluetooth를 켜세요. 이 시스템 설정은 Capsomnia가 꺼져 있어도 작동하며 핫스팟 암호가 필요하지 않습니다.", "近くのiPhoneのホットスポットを起動するには、macOS 26以降のWi-Fi設定で「ホットスポットへの接続を確認」を「自動」にします。同じApple Accountまたはファミリー共有を使い、Wi-FiとBluetoothをオンにしてください。このシステム設定はCapsomniaがオフでも機能し、パスワードは不要です。", "要唤醒附近的 iPhone 热点，请在 macOS 26 或更高版本的 Wi-Fi 设置中，将“询问是否加入热点”设为“自动”。使用同一 Apple 账户或家人共享，并开启 Wi-Fi 和蓝牙。此系统设置在 Capsomnia 关闭时也有效，无需热点密码。") }
    var saved: String { text("Password saved in Keychain.", "암호를 키체인에 저장했습니다.", "キーチェーンに保存しました。", "密码已保存到钥匙串。") }
    var forgotten: String { text("Password forgotten for this SSID.", "이 SSID의 암호를 삭제했습니다.", "このSSIDのパスワードを削除しました。", "已忘记此 SSID 的密码。") }
    var editFailed: String { text("Keychain change failed. Check access and try again. Existing credentials were not removed automatically.", "키체인 변경에 실패했습니다. 접근 권한을 확인하고 다시 시도하세요. 기존 암호는 자동 삭제되지 않았습니다.", "キーチェーンの変更に失敗しました。アクセス権を確認して再試行してください。既存の認証情報は自動削除されません。", "钥匙串更改失败。请检查访问权限后重试。现有凭据不会被自动删除。") }
    func status(_ status: HotspotReconnectStatus) -> String {
        switch status {
        case .disabled: return text("Auto-connect is off.", "자동 연결 꺼짐.", "自動接続はオフです。", "自动连接已关闭。")
        case .sessionInactive: return text("Ready when Capsomnia turns on.", "Capsomnia가 켜지면 대기합니다.", "Capsomniaがオンになると待機します。", "Capsomnia 开启后就绪。")
        case .needsSSID: return text("Enter a hotspot Wi-Fi name.", "핫스팟 Wi-Fi 이름을 입력하세요.", "ホットスポットのWi-Fi名を入力してください。", "请输入热点 Wi-Fi 名称。")
        case .ready: return text("Wi-Fi monitoring is ready.", "Wi-Fi 감시 준비 완료.", "Wi-Fi監視の準備ができました。", "Wi-Fi 监测已就绪。")
        case .waiting: return text("Waiting for Wi-Fi; retries use 5–30 second backoff.", "Wi-Fi 대기 중. 5~30초 간격으로 재시도합니다.", "Wi-Fiを待機中。5〜30秒間隔で再試行します。", "正在等待 Wi-Fi；重试间隔为 5 至 30 秒。")
        case .joining: return text("Joining saved hotspot…", "저장된 핫스팟 연결 중…", "保存したホットスポットに接続中…", "正在连接已保存的热点…")
        case .needsLocation: return text("Location access is needed to find Wi-Fi networks.", "Wi-Fi 검색을 위해 위치 접근이 필요합니다.", "Wi-Fi検索には位置情報の許可が必要です。", "查找 Wi-Fi 网络需要位置访问权限。")
        case .passwordMissing: return text("No saved password. Save one below.", "저장된 암호가 없습니다. 아래에서 저장하세요.", "パスワードがありません。下で保存してください。", "没有已保存的密码。请在下方保存。")
        case .passwordUnreadable: return text("Saved password cannot be read without a prompt. Check Keychain access or save it again.", "확인 대화상자 없이 암호를 읽을 수 없습니다. 키체인 접근을 확인하거나 다시 저장하세요.", "確認なしでパスワードを読めません。キーチェーンのアクセス権を確認するか再保存してください。", "无法在不提示的情况下读取密码。请检查钥匙串访问权限或重新保存。")
        case .targetNotVisible: return text("Hotspot not visible. Turn it on; retrying.", "핫스팟이 보이지 않습니다. 핫스팟을 켜세요. 재시도 중.", "ホットスポットが見つかりません。オンにしてください。再試行中です。", "热点不可见。请开启热点；正在重试。")
        case .interfaceUnavailable: return text("Wi-Fi interface unavailable; retrying.", "Wi-Fi 인터페이스를 사용할 수 없습니다. 재시도 중.", "Wi-Fiインターフェースが利用できません。再試行中です。", "Wi-Fi 接口不可用；正在重试。")
        case .associationFailed: return text("Hotspot connection failed. Check its password and availability; retrying.", "핫스팟 연결 실패. 암호와 핫스팟 상태를 확인하세요. 재시도 중.", "接続に失敗しました。パスワードとホットスポットを確認してください。再試行中です。", "热点连接失败。请检查密码和热点状态；正在重试。")
        }
    }
}
