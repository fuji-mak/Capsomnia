(function () {
  "use strict";

  var translations = {
    en: {
      title: "Capsomnia — Caps Lock as a physical keep-awake switch for macOS",
      description:
        "Capsomnia turns Caps Lock into a physical keep-awake switch for closed-lid MacBook background work. Run Codex, Claude Code, SSH sessions, builds, and unattended scripts without sleep.",
      skipLink: "Skip to content",
      navUses: "Use cases",
      navWhy: "Why",
      navInstall: "Install",
      navSecurity: "Security",
      heroTitle: 'Give Caps Lock<br><span class="catch-accent">a real job</span>',
      heroSub:
        "<strong>Caps Lock becomes a physical keep-awake switch.</strong> Flip it on, close the lid, and let your background work keep running.",
      installCta: "Install",
      stripLabel: "How it works",
      stripOnTitle: "Caps Lock on",
      stripOnSub: "Runs <code>pmset -a disablesleep 1</code> — sleep is disabled.",
      stripOffTitle: "Caps Lock off",
      stripOffSub: "Runs <code>pmset -a disablesleep 0</code> — normal sleep behavior.",
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
      whyTitle: "Why not <code>caffeinate</code>?",
      whyBodyOne:
        "<code>caffeinate</code> is useful while your Mac is open. But once you close the lid, running processes usually stop.",
      whyBodyTwo:
        "Capsomnia uses <code>pmset -a disablesleep 1</code> to disable system sleep itself. Local work can continue with the lid closed, and the Caps Lock LED shows the state without cluttering your screen.",
      compareCaffeinate: "Blocks idle sleep · lid open",
      compareCapsomnia: "Disables system sleep · lid closed",
      installTitle: "Install from source",
      installLede:
        "Capsomnia is distributed as source for now. The install script builds <code>Capsomnia.app</code> locally and sets everything up.",
      copyButton: "Copy",
      copiedButton: "Copied",
      stepOne: "Build <code>Capsomnia.app</code> locally.",
      stepTwo: "Place the app in <code>~/Applications/</code>.",
      stepThree: "Install the sleep-control helper.",
      stepFour: "Allow only the helper's <code>on</code>/<code>off</code>/<code>display-sleep</code> commands.",
      stepFive: "Register the LaunchAgent so Capsomnia starts at login.",
      installReq: "Requires macOS 14 or later, a Swift 6 toolchain, and administrator access during installation.",
      securityTitle: "Security model",
      securityLede:
        "The menu bar app runs as the current user — never as root. Changing system sleep settings needs elevated privileges, so Capsomnia uses one small, fixed, root-owned helper through passwordless <code>sudo</code>.",
      securityInvokeTitle: "The app can only invoke",
      securityInvokeBody: "The sudoers rule is limited to these three exact commands.",
      securityHelperTitle: "The helper only ever runs",
      securityHelperBody: "It accepts <code>on</code>, <code>off</code>, and <code>display-sleep</code> and nothing else.",
      securityReq:
        "Quitting the app, or running <code>./scripts/uninstall.sh</code>, restores normal sleep behavior. Sleep-disabled closed-lid use can increase heat and battery drain — mind airflow, power, and runtime.",
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
      navWhy: "理由",
      navInstall: "インストール",
      navSecurity: "安全性",
      heroTitle:
        'Macの<span class="catch-accent">最も無駄なキー</span>に<br><span class="catch-accent">最高の仕事</span>を与える',
      heroSub:
        "<strong>Caps Lockを物理的なスリープ防止スイッチに。</strong> オンにして蓋を閉じるだけで、バックグラウンド作業を走らせ続けます。",
      installCta: "インストール",
      stripLabel: "仕組み",
      stripOnTitle: "Caps Lock オン",
      stripOnSub: "<code>pmset -a disablesleep 1</code> を実行し、スリープを無効化します。",
      stripOffTitle: "Caps Lock オフ",
      stripOffSub: "<code>pmset -a disablesleep 0</code> を実行し、通常のスリープ動作に戻します。",
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
      whyTitle: "なぜ <code>caffeinate</code> ではないのか",
      whyBodyOne:
        "<code>caffeinate</code> は、Macを開いているときのアイドルスリープ防止には便利です。しかし、蓋を閉じれば実行中のプロセスは通常停止してしまいます。",
      whyBodyTwo:
        "Capsomniaは <code>pmset -a disablesleep 1</code> を使い、システムスリープそのものを無効化します。蓋を閉じてもローカル作業を続けられ、Caps LockのLEDがその状態を示すため画面を汚しません。",
      compareCaffeinate: "アイドルスリープを防ぐ · 蓋は開いたまま",
      compareCapsomnia: "システムスリープを無効化 · 蓋閉じ対応",
      installTitle: "ソースからインストール",
      installLede:
        "現在のCapsomniaはソース配布です。インストールスクリプトがローカルで <code>Capsomnia.app</code> をビルドし、必要な設定まで行います。",
      copyButton: "コピー",
      copiedButton: "コピー済み",
      stepOne: "<code>Capsomnia.app</code> をローカルでビルドします。",
      stepTwo: "アプリを <code>~/Applications/</code> に配置します。",
      stepThree: "スリープ制御用helperを配置します。",
      stepFour: "helperの <code>on</code>/<code>off</code>/<code>display-sleep</code> だけを許可します。",
      stepFive: "LaunchAgentを登録し、ログイン時に起動します。",
      installReq: "macOS 14以降、Swift 6 toolchain、インストール時の管理者権限が必要です。",
      securityTitle: "安全性の考え方",
      securityLede:
        "メニューバーアプリ本体は現在のユーザーとして動き、rootでは動きません。システムのスリープ設定変更には昇格権限が必要なため、Capsomniaは固定の小さなroot所有helperを、passwordless <code>sudo</code> 経由で呼び出します。",
      securityInvokeTitle: "アプリが呼べるのはこれだけ",
      securityInvokeBody: "sudoersルールは、この3つの完全一致コマンドだけに限定されています。",
      securityHelperTitle: "helperが実行するのはこれだけ",
      securityHelperBody: "<code>on</code>、<code>off</code>、<code>display-sleep</code> 以外は受け付けません。",
      securityReq:
        "アプリを終了するか <code>./scripts/uninstall.sh</code> を実行すると、通常のスリープ動作に戻ります。スリープ無効の蓋閉じ運用は、発熱やバッテリー消費が増えることがあります。通気、電源、実行時間には注意してください。",
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

  document.addEventListener("click", function (event) {
    var btn = event.target.closest(".copy-btn");
    if (!btn) return;

    var text = btn.getAttribute("data-copy");
    if (text == null) {
      var block = btn.parentElement.querySelector("pre code");
      text = block ? block.textContent : "";
    }

    function done() {
      var original = translations[currentLang].copyButton;
      btn.dataset.label = original;
      btn.textContent = translations[currentLang].copiedButton;
      btn.classList.add("is-copied");
      window.clearTimeout(btn._copyTimer);
      btn._copyTimer = window.setTimeout(function () {
        btn.textContent = btn.dataset.label;
        btn.classList.remove("is-copied");
      }, 1600);
    }

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback);
    } else {
      fallback();
    }

    function fallback() {
      var ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.position = "absolute";
      ta.style.left = "-9999px";
      document.body.appendChild(ta);
      ta.select();
      try {
        document.execCommand("copy");
        done();
      } catch (e) {
        /* no-op */
      }
      document.body.removeChild(ta);
    }
  });

  applyLanguage(currentLang);
})();
