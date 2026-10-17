import Foundation

struct LidOpenLockText {
    let title, description: String

    static var current: Self { localized(Preferences.language) }

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .simplifiedChinese:
            return Self(title: "开盖后自动锁定", description: "合盖保持运行时，开盖将锁定 Mac。锁定可能影响桌面自动化。")
        case .japanese:
            return Self(title: "蓋を開けたら画面をロック", description: "閉じたまま動作中、蓋を開くと Mac をロックします。画面操作の自動化に影響する場合があります。")
        case .korean:
            return Self(title: "덮개를 열면 자동 잠금", description: "덮개를 닫고 실행 중일 때 열면 Mac을 잠급니다. 화면 자동화에 영향을 줄 수 있습니다.")
        case .english:
            return Self(title: "Lock when lid opens", description: "Lock the Mac when opening the lid during closed-lid work. Locking may affect desktop automation.")
        }
    }
}
