import Foundation

struct LidOpenLockText {
    let title, description, inactive, history, empty, pending, confirmed, alreadyLocked: String
    let unconfirmed, unavailable, stateUnavailable, closed, opened, notRecorded, verified, reason, caution, acknowledge, viewRecord: String

    static var current: Self { localized(Preferences.language) }

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .simplifiedChinese:
            return Self(title: "开盖后自动锁定", description: "合盖保持运行时，开盖将锁定 Mac。锁定可能影响桌面自动化。",
                        inactive: "当前未生效：需开启 Capsomnia 和“使用 Computer Use 等工具”。",
                        history: "最近一次开盖锁定", empty: "尚未触发开盖锁定。", pending: "已请求锁定，等待系统确认",
                        confirmed: "因开盖自动锁定", alreadyLocked: "检测到开盖时已处于锁定状态", unconfirmed: "未能确认锁定",
                        unavailable: "锁定失败：系统锁定接口不可用", stateUnavailable: "未请求锁定：无法读取屏幕锁定状态",
                        closed: "最近一次合盖", opened: "检测到开盖", notRecorded: "未记录", verified: "确认已锁定",
                        reason: "此次锁定请求由开盖触发，发生在检测到开盖之后。",
                        caution: "如有浏览器自动化正在执行，请检查任务状态。",
                        acknowledge: "知道了", viewRecord: "查看记录")
        case .japanese:
            return Self(title: "蓋を開いたらロック", description: "閉じたまま動作中、蓋を開くと Mac をロックします。画面操作の自動化に影響する場合があります。",
                        inactive: "無効：Capsomnia と画面のスリープ防止をオンにしてください。",
                        history: "最近の開蓋ロック", empty: "開蓋ロックの記録はありません。", pending: "ロックを要求済み・確認待ち",
                        confirmed: "蓋を開いたためロック", alreadyLocked: "開蓋検出時にロック済み", unconfirmed: "ロックを確認できませんでした",
                        unavailable: "ロック失敗：システム機能が利用不可", stateUnavailable: "要求なし：ロック状態を取得できません",
                        closed: "最後に蓋を閉じた時刻", opened: "開蓋を検出", notRecorded: "記録なし", verified: "ロックを確認",
                        reason: "この要求は蓋を開いたことにより、開蓋検出後に行われました。",
                        caution: "ブラウザの自動化タスクの状態を確認してください。", acknowledge: "了解", viewRecord: "記録を表示")
        case .korean:
            return Self(title: "덮개를 열면 자동 잠금", description: "덮개를 닫고 실행 중일 때 열면 Mac을 잠급니다. 화면 자동화에 영향을 줄 수 있습니다.",
                        inactive: "비활성: Capsomnia와 화면 깨우기 기능을 켜세요.",
                        history: "최근 덮개 열기 잠금", empty: "잠금 기록이 없습니다.", pending: "잠금 요청됨 · 확인 대기",
                        confirmed: "덮개를 열어 자동 잠금", alreadyLocked: "열림 감지 시 이미 잠겨 있음", unconfirmed: "잠금을 확인하지 못함",
                        unavailable: "잠금 실패: 시스템 기능 사용 불가", stateUnavailable: "요청하지 않음: 잠금 상태를 읽을 수 없음",
                        closed: "최근 덮개 닫힘", opened: "덮개 열림 감지", notRecorded: "기록 없음", verified: "잠금 확인",
                        reason: "이 잠금 요청은 덮개 열림을 감지한 후 발생했습니다.",
                        caution: "실행 중인 브라우저 자동화 작업을 확인하세요.", acknowledge: "확인", viewRecord: "기록 보기")
        case .english:
            return Self(title: "Lock when lid opens", description: "Lock the Mac when opening the lid during closed-lid work. Locking may affect desktop automation.",
                        inactive: "Inactive: enable Capsomnia and keep-display-awake mode.",
                        history: "Last lid-open lock", empty: "No lid-open lock recorded.", pending: "Lock requested · awaiting confirmation",
                        confirmed: "Locked because the lid opened", alreadyLocked: "Already locked when lid opening was detected", unconfirmed: "Lock could not be confirmed",
                        unavailable: "Lock failed: system lock API unavailable", stateUnavailable: "No request: lock state unavailable",
                        closed: "Last lid closing", opened: "Lid opening detected", notRecorded: "Not recorded", verified: "Lock confirmed",
                        reason: "This lock request was triggered after detecting the lid opening.",
                        caution: "Check any browser automation that was running.", acknowledge: "Got it", viewRecord: "View record")
        }
    }

    func status(_ record: LidOpenLockRecord) -> String {
        switch record.outcome {
        case .pending: return pending
        case .locked: return confirmed
        case .alreadyLocked: return alreadyLocked
        case .unconfirmed: return unconfirmed
        case .unavailable: return unavailable
        case .stateUnavailable: return stateUnavailable
        }
    }

    func details(_ record: LidOpenLockRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
        var lines = [
            "\(closed)：\(record.closedAt.map { formatter.string(from: $0) } ?? notRecorded)",
            "\(opened)：\(formatter.string(from: record.openedAt))",
            "\(verified)：\(record.confirmedAt.map { formatter.string(from: $0) } ?? notRecorded)"
        ]
        if record.requestedAt != nil { lines.append(reason) }
        lines.append(caution)
        return lines.joined(separator: "\n")
    }
}
