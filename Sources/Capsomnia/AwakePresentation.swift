import AppKit

enum AwakePhase: Equatable {
    case off, on, starting, stopping, failed, unknown

    static func resolve(requested: Bool?, confirmed: Bool?, pending: Bool?, failed: Bool) -> Self {
        if let pending { return pending ? .starting : .stopping }
        if failed { return .failed }
        guard let requested, let confirmed else { return .unknown }
        if requested != confirmed { return requested ? .starting : .stopping }
        return confirmed ? .on : .off
    }
    var isPending: Bool { self == .starting || self == .stopping }
}

/// A single presentation shared by the settings window and menu; preferences
/// are deliberately separate from confirmed runtime capabilities.
struct AwakePresentation: Equatable {
    var phase: AwakePhase = .off
    var confirmedOn = false
    var computerUse = false
    var displayActive = false
    var inputPermissionIssue = false

    var canToggle: Bool { !phase.isPending && phase != .unknown }
    var color: NSColor {
        if inputPermissionIssue { return .systemRed }
        switch phase {
        case .on: return computerUse && !displayActive ? .systemOrange : Brand.led
        case .starting, .stopping: return .systemOrange
        case .failed, .unknown: return .systemRed
        case .off: return NSColor(calibratedWhite: 0.58, alpha: 1)
        }
    }
    func status(_ t: AwakeText) -> String {
        switch phase {
        case .off: return inputPermissionIssue ? t.off + " · " + t.inputIssue : t.off
        case .on: return inputPermissionIssue ? t.on + " · " + t.inputIssue : t.on
        case .starting: return t.starting
        case .stopping: return t.stopping
        case .failed: return t.failed
        case .unknown: return t.unknown
        }
    }
    func computerStatus(_ t: AwakeText) -> String {
        guard computerUse else { return t.computerOff }
        guard phase == .on else { return t.waitForMaster }
        return displayActive ? t.computerOn : t.displayUnavailable
    }
    func updateMenu(master: NSMenuItem?, status: NSMenuItem?, computer: NSMenuItem?,
                    computerStatus: NSMenuItem?, text t: AwakeText) {
        master?.title = t.title
        master?.state = confirmedOn ? .on : .off
        master?.isEnabled = canToggle
        status?.title = self.status(t)
        status?.isEnabled = false
        computer?.title = AppStrings.localized(for: t.language).keepDisplayAwake
        computer?.state = computerUse ? .on : .off
        computerStatus?.title = self.computerStatus(t)
        computerStatus?.isEnabled = false
    }

    func summary(_ t: AwakeText) -> String {
        switch phase {
        case .off: return t.offSummary
        case .starting, .stopping: return t.pendingSummary
        case .failed, .unknown: return t.failedSummary
        case .on:
            if computerUse && !displayActive { return t.displayUnavailable }
            if computerUse { return t.screenSummary }
            return t.backgroundSummary
        }
    }
}

struct AwakeText {
    let language: AppLanguage
    static var current: Self { Self(language: Preferences.language) }
    private func t(_ zh: String, _ en: String, _ ja: String, _ ko: String) -> String {
        switch language {
        case .simplifiedChinese: return zh
        case .english: return en
        case .japanese: return ja
        case .korean: return ko
        }
    }
    var title: String { t("保持运行", "Keep running", "動作を継続", "계속 실행") }
    var on: String { t("已开启", "On", "オン", "켜짐") }
    var off: String { t("已关闭 · 下方设置暂不生效", "Off · settings below are inactive", "オフ・下の設定は未適用", "꺼짐 · 아래 설정 비활성") }
    var starting: String { t("正在开启…", "Turning on…", "オンに切り替え中…", "켜는 중…") }
    var stopping: String { t("正在关闭…", "Turning off…", "オフに切り替え中…", "끄는 중…") }
    var failed: String { t("切换失败 · 请重试", "Switch failed · try again", "切り替え失敗・再試行してください", "전환 실패 · 다시 시도") }
    var unknown: String { t("无法确认运行状态", "Run state unavailable", "動作状態を確認できません", "실행 상태 확인 불가") }
    var inputIssue: String { t("输入辅助权限异常", "Input assistance needs permission", "入力補助の権限を確認", "입력 지원 권한 확인 필요") }
    var computerDescription: String { t("开启“保持运行”后，防止显示屏因空闲休眠；合盖时仅调暗内置屏幕，为点击、输入等屏幕自动操作保留运行环境。", "With Keep running on, prevent idle display sleep and dim the built-in screen when closed, supporting screen-based clicks and typing.", "動作を継続がオンの時、画面の自動スリープを抑止。蓋を閉じると内蔵画面だけを暗くし、クリックや入力の自動操作を支援します。", "계속 실행이 켜져 있으면 화면의 유휴 잠자기를 방지합니다. 덮개를 닫으면 내장 화면만 어둡게 해 클릭·입력 자동화를 지원합니다.") }
    var computerOff: String { t("已关闭：不额外保持桌面可用。", "Off: desktop availability is not maintained.", "オフ：画面操作環境を維持しません。", "꺼짐: 화면 조작 환경을 유지하지 않습니다.") }
    var computerOn: String { t("已生效：保持桌面可用。", "Active: keeping the desktop available.", "適用中：画面操作環境を維持します。", "적용 중: 화면 조작 환경 유지.") }
    var waitForMaster: String { t("已选中，待“保持运行”开启成功后生效。", "Selected; takes effect once Keep running is on.", "選択済み。「動作を継続」がオンになると適用。", "선택됨 · 계속 실행이 켜지면 적용됩니다.") }
    var displayUnavailable: String { t("保持运行已开启，但尚未确认桌面保持功能生效。", "Keep running is on, but desktop availability is not confirmed.", "動作は継続中ですが、画面維持は未確認です。", "계속 실행은 켜졌지만 화면 유지 기능은 확인되지 않았습니다.") }
    var offSummary: String { t("当前不会保持运行。开启后，才会按所选设置处理合盖和开盖。", "Keep running is off. Enable it to apply the selected lid behavior.", "現在は通常動作です。オンにすると蓋の開閉設定が適用されます。", "현재 계속 실행이 꺼져 있습니다. 켜면 선택한 덮개 설정이 적용됩니다.") }
    var pendingSummary: String { t("正在应用系统设置，请稍候。", "Applying system settings. Please wait.", "システム設定を適用しています。", "시스템 설정을 적용하고 있습니다.") }
    var failedSummary: String { t("尚未确认切换成功，请检查权限或重试；当前休眠行为不能确定。", "The change is not confirmed. Check permissions or retry; sleep behavior is uncertain.", "変更を確認できません。権限を確認して再試行してください。", "변경을 확인하지 못했습니다. 권한을 확인하거나 다시 시도하세요.") }
    var backgroundSummary: String { t("合盖后：后台任务继续，屏幕可锁定。\n开盖后：按系统正常行为处理。", "Lid closed: background work continues; the screen may lock.\nLid opened: normal system behavior.", "閉じた時：バックグラウンド処理を継続。画面はロック可能。\n開いた時：通常のシステム動作。", "닫으면: 백그라운드 작업 계속, 화면 잠금 가능.\n열면: 시스템 기본 동작.") }
    var screenSummary: String { t("合盖后：保留屏幕操作环境。\n开盖后：本应用不主动锁定。", "Lid closed: preserve the screen-operation environment.\nLid opened: this app does not request a lock.", "閉じた時：画面操作環境を維持。\n開いた時：このアプリはロックしません。", "닫으면: 화면 조작 환경 유지.\n열면: 이 앱에서 잠금을 요청하지 않음.") }
    var autoEnd: String { t("自动结束", "Auto end", "自動終了", "자동 종료") }
    var never: String { t("不自动结束", "No auto end", "自動終了しない", "자동 종료 안 함") }
    var power: String { t("长时间合盖运行建议连接电源。", "Power is recommended for long closed-lid sessions.", "長時間の合蓋動作では電源接続をおすすめします。", "덮개를 닫고 오래 사용할 때는 전원 연결을 권장합니다.") }
}
