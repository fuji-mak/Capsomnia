(function () {
  "use strict";

  var translations = {
    en: {
      title: "Capsomnia — Caps Lock as a physical keep-awake switch for macOS",
      description:
        "Capsomnia turns Caps Lock into a physical keep-awake switch for closed-lid MacBook background work. Run Codex, Claude Code, SSH sessions, builds, and unattended scripts without sleep.",
      skipLink: "Skip to content",
      navUses: "Use cases",
      navFeatures: "Features",
      navSecurity: "Security",
      heroTitle: 'Give Caps Lock<br><span class="catch-accent">a real job</span>',
      heroSub:
        "<strong>Caps Lock becomes a physical keep-awake switch.</strong> Flip it on, close the lid, and let your background work keep running.",
      downloadCta: "Download",
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
      securityInvokeBody: "The sudoers rule is limited to these three exact commands.",
      securityHelperTitle: "The helper only ever runs",
      securityHelperBody: "It accepts <code>on</code>, <code>off</code>, and <code>display-sleep</code> and nothing else.",
      securityInputTitle: "Input Monitoring is optional",
      securityInputBody:
        "Capsomnia uses it only to detect Caps Lock changes immediately. It does not read typed text, and it falls back to a one-second Caps Lock check if you skip the permission.",
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
      linkSecurityTitle: "Security policy",
      linkSecuritySub: "Reporting &amp; model",
      footerCatch: "Give Caps Lock a real job"
    },
    ja: {
      title: "Capsomnia — Caps LockをMacの物理スリープ防止スイッチに",
      description:
        "CapsomniaはCaps Lockを、蓋を閉じたMacBookでも作業を止めないための物理スイッチに変えるmacOSアプリです。Codex、Claude Code、SSH、ビルド、ダウンロード、放置スクリプト向け。",
      skipLink: "本文へ移動",
      navUses: "用途",
      navFeatures: "特徴",
      navSecurity: "安全性",
      heroTitle:
        'Macの<span class="catch-accent">最も無駄なキー</span>に<br><span class="catch-accent">最高の仕事</span>を与える',
      heroSub:
        "<strong>Caps Lockを物理的なスリープ防止スイッチに。</strong> オンにして蓋を閉じるだけで、バックグラウンド作業を走らせ続けます。",
      downloadCta: "ダウンロード",
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
      securityInvokeBody: "sudoersルールは、この3つの完全一致コマンドだけに限定されています。",
      securityHelperTitle: "helperが実行するのはこれだけ",
      securityHelperBody: "<code>on</code>、<code>off</code>、<code>display-sleep</code> 以外は受け付けません。",
      securityInputTitle: "入力監視は任意です",
      securityInputBody:
        "CapsomniaはCaps Lockの切り替えをすぐ検知するためだけに使います。入力内容は読みません。許可しない場合も、1秒ごとのCaps Lock状態確認で動作します。",
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
      linkSecurityTitle: "セキュリティポリシー",
      linkSecuritySub: "報告方法と安全性モデル",
      footerCatch: "Macの最も無駄なキーに最高の仕事を与える"
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
    return lang === "ja" || lang === "en" ? lang : null;
  }

  function detectInitialLanguage() {
    var stored = normalizeLanguage(readStoredValue("capsomnia-lang"));
    if (stored) return stored;

    var timeZone = "";
    try {
      timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
    } catch (e) {
      /* Fall back to browser languages below. */
    }

    if (timeZone === "Asia/Tokyo") return "ja";
    if (timeZone) return "en";

    var languages = [];
    try {
      if (window.navigator.languages && window.navigator.languages.length) {
        languages = Array.prototype.slice.call(window.navigator.languages);
      } else if (window.navigator.language) {
        languages = [window.navigator.language];
      }
    } catch (e) {
      /* Default to English below. */
    }

    var hasJapaneseLanguage = languages.some(function (lang) {
      return String(lang).toLowerCase().indexOf("ja") === 0;
    });

    return hasJapaneseLanguage ? "ja" : "en";
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

    document.querySelectorAll("[data-i18n-aria-label]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-aria-label");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("aria-label", dict[key]);
      }
    });

    document.querySelectorAll("[data-i18n-alt]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-alt");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("alt", dict[key]);
      }
    });

    document.querySelectorAll("[data-i18n-src]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-src");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("src", dict[key]);
      }
    });

    document.querySelectorAll("[data-i18n-width]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-width");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("width", dict[key]);
      }
    });

    document.querySelectorAll("[data-i18n-height]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-height");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("height", dict[key]);
      }
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
