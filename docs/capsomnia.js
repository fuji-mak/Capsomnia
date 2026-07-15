(function () {
  "use strict";

  var translations = {
    en: {
      title: "Capsomnia — Caps Lock as a physical keep-awake switch for macOS",
      description:
        "Capsomnia turns Caps Lock into a physical keep-awake switch for closed-lid MacBook background work. Run Codex, Claude Code, SSH sessions, builds, and unattended scripts without sleep.",
      skipLink: "Skip to content",
      navLabel: "Main navigation",
      languageLabel: "Language",
      navUses: "Use cases",
      navFeatures: "Features",
      navSecurity: "Security",
      heroIconAlt: "Capsomnia LED icon",
      heroTitle: 'Give Caps Lock<br><span class="catch-accent">a real job</span>',
      heroSub:
        "<strong>Caps Lock becomes a physical keep-awake switch.</strong> Flip it on, close the lid, and let your background work keep running.",
      downloadCta: "Download",
      downloadLabel: "Download Capsomnia",
      stripLabel: "How it works",
      stripOnTitle: "Caps Lock on",
      stripOnSub: "Runs <code>pmset -a disablesleep 1</code> — sleep is disabled.",
      stripOffTitle: "Caps Lock off",
      stripOffSub: "Runs <code>pmset -a disablesleep 0</code> — normal sleep behavior.",
      previewLabel: "Capsomnia app preview",
      previewAlt: "Capsomnia settings window",
      previewSrc: "app-preview-en.png",
      previewWidth: "800",
      previewHeight: "1038",
      usesTitle: "A physical switch for AI agents",
      usesLede:
        "Flip Caps Lock on, close the lid, and let long-running local work continue. Capsomnia keeps your MacBook awake until you turn it off. The Caps Lock LED shows the sleep-prevention state at a glance.",
      cardAgentsTitle: "AI agents",
      cardAgentsBody: "Keep long Codex or Claude Code tasks running with the lid closed.",
      cardSshTitle: "SSH sessions",
      cardSshBody: "Drive your Mac remotely without it dropping into sleep mid-session.",
      cardBuildsTitle: "Builds &amp; downloads",
      cardBuildsBody: "Long compiles and large downloads finish on their own time.",
      cardScriptsTitle: "Mobile connections",
      cardScriptsBody: "Keep Codex Mobile and other mobile sessions connected so work does not stop.",
      featuresEyebrow: "Features",
      featuresTitle: "Keep your Mac working after the lid closes",
      featuresLede:
        "Capsomnia is a small Mac app focused on closed-lid continuity, physical status visibility, and transparent open-source design.",
      featureClosedKicker: "Closed lid",
      featureClosedTitle: "Keeps work running with the lid closed",
      featureClosedBody:
        "Turn Caps Lock on, close the MacBook, and local jobs keep running. Your Mac can remain reachable over SSH when remote login and networking are available.",
      featureLedKicker: "Physical state",
      featureLedTitle: "The Caps Lock LED shows status",
      featureLedBody:
        "When the light is on, sleep prevention is on. You can check the state from the keyboard and keep your menu bar clean.",
      featureOssKicker: "Open source",
      featureOssTitle: "Completely free, open-source design",
      featureOssBody:
        "Released under the MIT License. You can inspect the source, package install scripts, helper commands, and security model before installing.",
      securityTitle: "Security model",
      securityLede:
        "The menu bar app runs as the current user — never as root. Changing system sleep settings needs elevated privileges, so Capsomnia uses one small, fixed, root-owned helper through passwordless <code>sudo</code>.",
      securityOfflineLabel: "Privacy",
      securityOfflineNetwork: "No network requests",
      securityOfflineTelemetry: "No telemetry",
      securityOfflineAccounts: "No accounts",
      securityInvokeTitle: "The app can only invoke",
      securityInvokeBody: "The package keeps the app, helper, and system LaunchAgent root-owned. The sudoers rule is limited to these three exact commands.",
      securityHelperTitle: "The helper only ever runs",
      securityHelperBody: "It accepts <code>on</code>, <code>off</code>, and <code>display-sleep</code> and nothing else.",
      securityInputTitle: "No Input Monitoring",
      securityInputBody:
        "Capsomnia does not read keyboard events. It checks only the local Caps Lock state every 250 milliseconds.",
      securityBackgroundTitle: "Background item prompt",
      securityBackgroundBody:
        "macOS may show “Taketo Fujimaki” as a background item. This is the LaunchAgent that starts Capsomnia at login and recovers after crashes.",
      securityReq:
        "Quitting the app restores normal sleep behavior. Sleep-disabled closed-lid use can increase heat and battery drain — mind airflow, power, and runtime.",
      linksTitle: "Links",
      linkRepoTitle: "GitHub repository",
      linkRepoSub: "Source, issues, releases",
      linkReadmeSub: "Full documentation",
      linkReadmeJaSub: "Japanese documentation",
      linkReadmeKoSub: "Korean documentation",
      linkSecurityTitle: "Security policy",
      linkSecuritySub: "Reporting &amp; model",
      footerCatch: "Give Caps Lock a real job"
    },
    ja: {
      title: "Capsomnia — Caps LockをMacの物理スリープ防止スイッチに",
      description:
        "CapsomniaはCaps Lockを、蓋を閉じたMacBookでも作業を止めないための物理スイッチに変えるmacOSアプリです。Codex、Claude Code、SSH、ビルド、ダウンロード、放置スクリプト向け。",
      skipLink: "本文へ移動",
      navLabel: "メインナビゲーション",
      languageLabel: "言語",
      navUses: "用途",
      navFeatures: "特徴",
      navSecurity: "安全性",
      heroIconAlt: "CapsomniaのLEDアイコン",
      heroTitle:
        'Macの<span class="catch-accent">最も無駄なキー</span>に<br><span class="catch-accent">最高の仕事</span>を与える',
      heroSub:
        "<strong>Caps Lockを物理的なスリープ防止スイッチに。</strong> オンにして蓋を閉じるだけで、バックグラウンド作業を走らせ続けます。",
      downloadCta: "ダウンロード",
      downloadLabel: "Capsomniaをダウンロード",
      stripLabel: "仕組み",
      stripOnTitle: "Caps Lock オン",
      stripOnSub: "<code>pmset -a disablesleep 1</code> を実行し、スリープを無効化します。",
      stripOffTitle: "Caps Lock オフ",
      stripOffSub: "<code>pmset -a disablesleep 0</code> を実行し、通常のスリープ動作に戻します。",
      previewLabel: "Capsomniaアプリのプレビュー",
      previewAlt: "Capsomniaの設定画面",
      previewSrc: "app-preview-framed.png",
      previewWidth: "800",
      previewHeight: "1020",
      usesTitle: "AIエージェントのための物理スイッチ",
      usesLede:
        "長時間走らせたいローカル作業があるときは、Caps Lockをオンにして蓋を閉じるだけ。Capsomniaが、オフに戻すまでMacBookを起こしたままにします。Caps LockのLEDが、スリープ防止の状態を視覚的に示します。",
      cardAgentsTitle: "AIエージェント",
      cardAgentsBody: "CodexやClaude Codeの長い作業を、蓋を閉じたまま走らせます。",
      cardSshTitle: "SSHセッション",
      cardSshBody: "リモートからMacを触っている途中で、スリープに落ちるのを防ぎます。",
      cardBuildsTitle: "ビルドとダウンロード",
      cardBuildsBody: "長いコンパイルや大きなダウンロードを最後まで進めます。",
      cardScriptsTitle: "モバイル接続",
      cardScriptsBody: "Codex Mobile等のモバイル接続を維持し、作業を止めません。",
      featuresEyebrow: "Features",
      featuresTitle: "蓋を閉じても、Macを仕事中にする",
      featuresLede:
        "Capsomniaは、蓋閉じ作業の継続、物理ライトでの状態確認、無料OSSとしての透明性に絞った小さなMacアプリです。",
      featureClosedKicker: "Closed lid",
      featureClosedTitle: "蓋を閉じても処理が続行",
      featureClosedBody:
        "Caps Lockをオンにすれば、MacBookの蓋を閉じてもローカル処理を走らせ続けます。SSH接続先としても使い続けられます。",
      featureLedKicker: "Physical state",
      featureLedTitle: "Caps Lockのライトで状態確認",
      featureLedBody:
        "ランプが点いていればスリープ抑止中。メニューバー表示なしでも分かるので、画面を汚しません。",
      featureOssKicker: "Open source",
      featureOssTitle: "完全無料、OSS公開で安心設計",
      featureOssBody:
        "MIT Licenseで公開。ソースコード、パッケージのインストール処理、helperが実行できるコマンド、安全性モデルを確認できます。",
      securityTitle: "安全性の考え方",
      securityLede:
        "メニューバーアプリ本体は現在のユーザーとして動き、rootでは動きません。システムのスリープ設定変更には昇格権限が必要なため、Capsomniaは固定の小さなroot所有helperを、passwordless <code>sudo</code> 経由で呼び出します。",
      securityOfflineLabel: "プライバシー",
      securityOfflineNetwork: "ネットワーク通信なし",
      securityOfflineTelemetry: "テレメトリなし",
      securityOfflineAccounts: "アカウント不要",
      securityInvokeTitle: "アプリが呼べるのはこれだけ",
      securityInvokeBody: "パッケージ版のアプリ、helper、システムLaunchAgentはroot所有です。sudoersルールは、この3つの完全一致コマンドだけに限定されています。",
      securityHelperTitle: "helperが実行するのはこれだけ",
      securityHelperBody: "<code>on</code>、<code>off</code>、<code>display-sleep</code> 以外は受け付けません。",
      securityInputTitle: "入力監視は不要",
      securityInputBody:
        "Capsomniaはキーボードイベントを読みません。ローカルのCaps Lock状態だけを250ミリ秒ごとに確認します。",
      securityBackgroundTitle: "バックグラウンド項目の表示",
      securityBackgroundBody:
        "macOSが「Taketo Fujimaki」のバックグラウンド項目を表示することがあります。これはログイン時にCapsomniaを起動し、クラッシュ後に復帰するためのLaunchAgentです。",
      securityReq:
        "アプリを終了すると通常のスリープ動作に戻ります。スリープ無効の蓋閉じ運用は、発熱やバッテリー消費が増えることがあります。通気、電源、実行時間には注意してください。",
      linksTitle: "リンク",
      linkRepoTitle: "GitHubリポジトリ",
      linkRepoSub: "ソースコード、Issue、Release",
      linkReadmeSub: "英語ドキュメント",
      linkReadmeJaSub: "日本語ドキュメント",
      linkReadmeKoSub: "韓国語ドキュメント",
      linkSecurityTitle: "セキュリティポリシー",
      linkSecuritySub: "報告方法と安全性モデル",
      footerCatch: "Macの最も無駄なキーに最高の仕事を与える"
    },
    ko: {
      title: "Capsomnia — Caps Lock을 macOS 잠자기 방지 스위치로",
      description:
        "Capsomnia는 Caps Lock을 MacBook 덮개를 닫은 채 작업할 때 쓰는 물리적인 잠자기 방지 스위치로 바꿔 주는 macOS 앱입니다. Codex, Claude Code, SSH 세션, 빌드, 다운로드, 무인 스크립트에 유용합니다.",
      skipLink: "본문으로 바로 가기",
      navLabel: "주요 메뉴",
      languageLabel: "언어",
      navUses: "활용 예",
      navFeatures: "기능",
      navSecurity: "보안",
      heroIconAlt: "Capsomnia LED 아이콘",
      heroTitle: 'Caps Lock에<br><span class="catch-accent">제대로 된 일을 맡기세요</span>',
      heroSub:
        "<strong>Caps Lock이 물리적인 잠자기 방지 스위치가 됩니다.</strong> 켜고 덮개를 닫으면 백그라운드 작업은 그대로 이어집니다.",
      downloadCta: "다운로드",
      downloadLabel: "Capsomnia 다운로드",
      stripLabel: "작동 방식",
      stripOnTitle: "Caps Lock 켜기",
      stripOnSub: "<code>pmset -a disablesleep 1</code>을 실행해 잠자기를 막습니다.",
      stripOffTitle: "Caps Lock 끄기",
      stripOffSub: "<code>pmset -a disablesleep 0</code>을 실행해 평소 잠자기 동작으로 돌아갑니다.",
      previewLabel: "Capsomnia 앱 미리 보기",
      previewAlt: "Capsomnia 설정 화면",
      previewSrc: "app-preview-en.png",
      previewWidth: "800",
      previewHeight: "1038",
      usesTitle: "AI 에이전트를 위한 물리 스위치",
      usesLede:
        "오래 걸리는 로컬 작업이 있다면 Caps Lock을 켜고 덮개를 닫으세요. 다시 끌 때까지 Capsomnia가 MacBook을 깨워 둡니다. 잠자기 방지 상태는 Caps Lock 표시등으로 바로 확인할 수 있습니다.",
      cardAgentsTitle: "AI 에이전트",
      cardAgentsBody: "덮개를 닫아도 Codex나 Claude Code의 긴 작업을 계속 돌립니다.",
      cardSshTitle: "SSH 세션",
      cardSshBody: "원격으로 Mac을 쓰는 도중 잠자기에 들어가 연결이 끊기는 일을 막습니다.",
      cardBuildsTitle: "빌드와 다운로드",
      cardBuildsBody: "오래 걸리는 컴파일과 큰 파일 다운로드가 끝까지 이어집니다.",
      cardScriptsTitle: "모바일 연결",
      cardScriptsBody: "Codex Mobile 같은 모바일 연결을 유지해 작업이 멈추지 않게 합니다.",
      featuresEyebrow: "기능",
      featuresTitle: "덮개를 닫아도 Mac은 계속 일합니다",
      featuresLede:
        "Capsomnia는 덮개를 닫아도 작업이 끊기지 않게 하고 Caps Lock 표시등으로 상태를 알려 주는 작은 Mac 앱입니다. 소스 코드도 모두 공개합니다.",
      featureClosedKicker: "덮개 닫기",
      featureClosedTitle: "덮개를 닫아도 작업은 계속됩니다",
      featureClosedBody:
        "Caps Lock을 켜고 MacBook 덮개를 닫아도 로컬 작업은 계속 실행됩니다. 원격 로그인과 네트워크가 켜져 있으면 SSH 접속도 유지됩니다.",
      featureLedKicker: "물리 표시",
      featureLedTitle: "Caps Lock 표시등으로 상태 확인",
      featureLedBody:
        "불이 켜져 있으면 잠자기 방지 기능도 켜진 상태입니다. 키보드만 보고 확인할 수 있어 메뉴 막대에 아이콘을 띄우지 않아도 됩니다.",
      featureOssKicker: "오픈 소스",
      featureOssTitle: "무료 오픈 소스",
      featureOssBody:
        "MIT 라이선스로 공개합니다. 설치 전에 소스 코드, 패키지 설치 스크립트, helper 명령, 보안 모델을 직접 살펴볼 수 있습니다.",
      securityTitle: "보안 모델",
      securityLede:
        "메뉴 막대 앱은 root가 아닌 현재 사용자 권한으로 실행됩니다. 시스템 잠자기 설정을 바꿀 때만 root가 소유한 고정 기능 helper 하나를 비밀번호 없는 <code>sudo</code>로 호출합니다.",
      securityOfflineLabel: "개인정보 보호",
      securityOfflineNetwork: "네트워크 연결 없음",
      securityOfflineTelemetry: "텔레메트리 없음",
      securityOfflineAccounts: "계정 불필요",
      securityInvokeTitle: "앱이 호출할 수 있는 명령",
      securityInvokeBody:
        "패키지로 설치한 앱, helper, 시스템 LaunchAgent의 소유자는 root입니다. sudoers 규칙은 정확히 이 세 명령만 허용합니다.",
      securityHelperTitle: "helper가 실행하는 명령",
      securityHelperBody: "<code>on</code>, <code>off</code>, <code>display-sleep</code> 외에는 받아들이지 않습니다.",
      securityInputTitle: "입력 모니터링 불필요",
      securityInputBody: "Capsomnia는 키보드 이벤트를 읽지 않습니다. 로컬 Caps Lock 상태만 250밀리초마다 확인합니다.",
      securityBackgroundTitle: "백그라운드 항목 안내",
      securityBackgroundBody:
        "macOS에 ‘Taketo Fujimaki’ 백그라운드 항목이 표시될 수 있습니다. 로그인할 때 Capsomnia를 시작하고 충돌 후 다시 실행하는 LaunchAgent입니다.",
      securityReq:
        "앱을 종료하면 평소 잠자기 동작으로 돌아갑니다. 잠자기를 막은 채 덮개를 닫으면 발열과 배터리 소모가 늘 수 있으니 통풍, 전원, 실행 시간을 확인하세요.",
      linksTitle: "링크",
      linkRepoTitle: "GitHub 저장소",
      linkRepoSub: "소스 코드, 이슈, 릴리스",
      linkReadmeSub: "영문 문서",
      linkReadmeJaSub: "일본어 문서",
      linkReadmeKoSub: "한국어 문서",
      linkSecurityTitle: "보안 정책",
      linkSecuritySub: "신고 방법과 보안 모델",
      footerCatch: "Caps Lock에 제대로 된 일을 맡기세요"
    }
  };

  function readStoredValue(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function storeValue(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (e) {
      /* Ignore storage failures. In-page switches should still work. */
    }
  }

  function normalizeLanguage(lang) {
    return lang === "ja" || lang === "en" || lang === "ko" ? lang : null;
  }

  function detectInitialLanguage() {
    var stored = normalizeLanguage(readStoredValue("capsomnia-lang"));
    if (stored) return stored;

    // The canonical URL is Japanese. Geo-adaptive defaults let US-based
    // crawlers render and index the English variant instead. English remains
    // available through the explicit language switch and is saved here.
    return "ja";
  }

  var currentLang = detectInitialLanguage();

  function applyLanguage(lang) {
    var dict = translations[lang] || translations.en;
    currentLang = lang;
    document.documentElement.lang = lang;
    document.title = dict.title;

    var description = document.querySelector('meta[name="description"]');
    if (description) description.setAttribute("content", dict.description);

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.innerHTML = dict[key];
      }
    });

    ["aria-label", "alt", "src", "width", "height"].forEach(function (attr) {
      var dataAttr = "data-i18n-" + attr;
      document.querySelectorAll("[" + dataAttr + "]").forEach(function (el) {
        var key = el.getAttribute(dataAttr);
        if (Object.prototype.hasOwnProperty.call(dict, key)) {
          el.setAttribute(attr, dict[key]);
        }
      });
    });

    document.querySelectorAll("[data-lang-option]").forEach(function (btn) {
      btn.setAttribute("aria-pressed", String(btn.getAttribute("data-lang-option") === lang));
    });

    storeValue("capsomnia-lang", lang);
  }

  document.addEventListener("click", function (event) {
    var langBtn = event.target.closest("[data-lang-option]");
    if (!langBtn) return;
    applyLanguage(langBtn.getAttribute("data-lang-option"));
  });

  applyLanguage(currentLang);
})();
