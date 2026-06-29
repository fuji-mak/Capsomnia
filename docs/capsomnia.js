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
      eyebrow: "macOS menu bar utility",
      heroTitle: "Give the Mac's most wasted key<br>its best job",
      heroSub:
        "<strong>Caps Lock becomes a physical keep-awake switch.</strong> Flip it on, close the lid, and let your background work keep running.",
      installCta: "Install from source",
      stripLabel: "How it works",
      stripOnTitle: "Caps Lock on",
      stripOnSub: "Runs <code>pmset -a disablesleep 1</code> — sleep is disabled.",
      stripOffTitle: "Caps Lock off",
      stripOffSub: "Runs <code>pmset -a disablesleep 0</code> — normal sleep behavior.",
      usesTitle: "One switch for closed-lid work",
      usesLede:
        "When a long-running local job should keep going while you step away, flip Caps Lock on. Close the lid. Capsomnia keeps the machine awake until you flip it back.",
      usesLedeSub:
        "For AI agents, SSH sessions, builds, downloads, and scripts that should keep running unattended.",
      cardAgentsTitle: "AI coding agents",
      cardAgentsBody: "Let Codex or Claude Code keep working on long tasks while the lid is shut.",
      cardSshTitle: "SSH sessions",
      cardSshBody: "Drive your Mac remotely without it dropping into sleep mid-session.",
      cardBuildsTitle: "Builds &amp; downloads",
      cardBuildsBody: "Long compiles and large downloads finish on their own time.",
      cardScriptsTitle: "Unattended scripts",
      cardScriptsBody: "Batch jobs and overnight scripts run to completion, untouched.",
      whyTitle: "Why not <code>caffeinate</code>?",
      whyBodyOne:
        "<code>caffeinate</code> is great at preventing <em>idle</em> sleep while your Mac is open. Closing the lid is a different problem: ordinary <code>caffeinate</code> assertions do not reliably keep local jobs running in closed-lid use.",
      whyBodyTwo:
        "Capsomnia uses <code>pmset -a disablesleep 1</code>, which disables system sleep itself — the right tool when you explicitly want local work to continue with the lid closed.",
      compareCaffeinate: "Blocks idle sleep · lid open",
      compareCapsomnia: "Disables system sleep · lid closed",
      compareNote: 'A manual switch: on means "keep running", off means "normal sleep".',
      installTitle: "Install from source",
      installLede:
        "Capsomnia is distributed as source for now. The install script builds <code>Capsomnia.app</code> locally and sets everything up.",
      copyButton: "Copy",
      copiedButton: "Copied",
      stepOne: "Builds the Swift executable in release mode.",
      stepTwo: "Builds and installs <code>Capsomnia.app</code> into <code>~/Applications/</code>.",
      stepThree:
        "Installs a root-owned helper at <code>/Library/PrivilegedHelperTools/capsomnia-pmset</code>.",
      stepFour: "Adds a narrow sudoers rule for the current user.",
      stepFive: "Installs and starts a LaunchAgent — the app launches at login.",
      installReq:
        "Requires macOS 14 or later, a Swift 6 toolchain, and administrator access during installation.",
      securityTitle: "Security model",
      securityLede:
        "The menu bar app runs as the current user — never as root. Changing system sleep settings needs elevated privileges, so Capsomnia uses one small, fixed, root-owned helper through passwordless <code>sudo</code>.",
      securityInvokeTitle: "The app can only invoke",
      securityInvokeBody: "The sudoers rule is limited to these two exact commands.",
      securityHelperTitle: "The helper only ever runs",
      securityHelperBody: "It accepts <code>on</code> and <code>off</code> and nothing else.",
      securityReq:
        "Quitting the app, or running <code>./scripts/uninstall.sh</code>, restores normal sleep behavior. Sleep-disabled closed-lid use can increase heat and battery drain — mind airflow, power, and runtime.",
      linksTitle: "Links",
      linkRepoTitle: "GitHub repository",
      linkRepoSub: "Source, issues, releases",
      linkReadmeSub: "Full documentation",
      linkReadmeJaSub: "Japanese documentation",
      linkSecurityTitle: "Security policy",
      linkSecuritySub: "Reporting &amp; model",
      footerCatch: "Give the Mac's most wasted key its best job"
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
      eyebrow: "macOSメニューバーアプリ",
      heroTitle: "Macの最も無駄なキーに<br>最高の仕事を与える",
      heroSub:
        "<strong>Caps Lockを物理的なスリープ防止スイッチに。</strong> オンにして蓋を閉じるだけで、バックグラウンド作業を走らせ続けます。",
      installCta: "ソースからインストール",
      stripLabel: "仕組み",
      stripOnTitle: "Caps Lock オン",
      stripOnSub: "<code>pmset -a disablesleep 1</code> を実行し、スリープを無効化します。",
      stripOffTitle: "Caps Lock オフ",
      stripOffSub: "<code>pmset -a disablesleep 0</code> を実行し、通常のスリープ動作に戻します。",
      usesTitle: "蓋閉じ作業のための物理スイッチ",
      usesLede:
        "長時間走らせたいローカル作業があるときは、Caps Lockをオンにして蓋を閉じるだけ。Capsomniaが、オフに戻すまでMacを起こしたままにします。",
      usesLedeSub:
        "AIエージェント、SSH、ビルド、ダウンロード、放置スクリプトを止めたくない場面に向いています。",
      cardAgentsTitle: "AIコーディングエージェント",
      cardAgentsBody: "CodexやClaude Codeの長い作業を、蓋を閉じたまま走らせます。",
      cardSshTitle: "SSHセッション",
      cardSshBody: "リモートからMacを触っている途中で、スリープに落ちるのを防ぎます。",
      cardBuildsTitle: "ビルドとダウンロード",
      cardBuildsBody: "長いコンパイルや大きなダウンロードを最後まで進めます。",
      cardScriptsTitle: "放置スクリプト",
      cardScriptsBody: "バッチ処理や夜間ジョブを、触らずに完走させます。",
      whyTitle: "なぜ <code>caffeinate</code> ではないのか",
      whyBodyOne:
        "<code>caffeinate</code> は、Macを開いているときのアイドルスリープ防止には便利です。ただ、蓋を閉じるケースは別問題です。通常の <code>caffeinate</code> assertion では、蓋閉じ状態のローカルジョブ継続を安定して保証できません。",
      whyBodyTwo:
        "Capsomniaは <code>pmset -a disablesleep 1</code> を使い、システムスリープそのものを無効化します。蓋を閉じてもローカル作業を続けたいときに、明示的に使うための仕組みです。",
      compareCaffeinate: "アイドルスリープを防ぐ · 蓋は開いたまま",
      compareCapsomnia: "システムスリープを無効化 · 蓋閉じ対応",
      compareNote: "オンなら走らせ続ける。オフなら通常のスリープに戻す。そういう手動スイッチです。",
      installTitle: "ソースからインストール",
      installLede:
        "現時点のCapsomniaはソース配布です。インストールスクリプトがローカルで <code>Capsomnia.app</code> をビルドし、必要な設定まで行います。",
      copyButton: "コピー",
      copiedButton: "コピー済み",
      stepOne: "Swift実行ファイルをrelease modeでビルドします。",
      stepTwo: "<code>Capsomnia.app</code> をビルドし、<code>~/Applications/</code> に配置します。",
      stepThree:
        "root所有のhelperを <code>/Library/PrivilegedHelperTools/capsomnia-pmset</code> に配置します。",
      stepFour: "現在のユーザー向けに、範囲を絞ったsudoersルールを追加します。",
      stepFive: "LaunchAgentを配置して起動します。ログイン時にアプリが起動します。",
      installReq:
        "macOS 14以降、Swift 6 toolchain、インストール時の管理者権限が必要です。",
      securityTitle: "安全性の考え方",
      securityLede:
        "メニューバーアプリ本体は現在のユーザーとして動き、rootでは動きません。システムのスリープ設定変更には昇格権限が必要なため、Capsomniaは固定の小さなroot所有helperを、passwordless <code>sudo</code> 経由で呼び出します。",
      securityInvokeTitle: "アプリが呼べるのはこれだけ",
      securityInvokeBody: "sudoersルールは、この2つの完全一致コマンドだけに限定されています。",
      securityHelperTitle: "helperが実行するのはこれだけ",
      securityHelperBody: "<code>on</code> と <code>off</code> 以外は受け付けません。",
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

  var currentLang =
    readStoredValue("capsomnia-lang") ||
    (window.navigator.language && window.navigator.language.indexOf("ja") === 0 ? "ja" : "en");

  var currentTheme =
    readStoredValue("capsomnia-theme") ||
    (window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");

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

  function applyTheme(theme) {
    currentTheme = theme === "light" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", currentTheme);

    var themeColor = document.querySelector('meta[name="theme-color"]');
    if (themeColor) {
      themeColor.setAttribute("content", currentTheme === "light" ? "#ffffff" : "#000000");
    }

    document.querySelectorAll("[data-theme-option]").forEach(function (btn) {
      btn.setAttribute("aria-pressed", String(btn.getAttribute("data-theme-option") === currentTheme));
    });

    storeValue("capsomnia-theme", currentTheme);
  }

  document.addEventListener("click", function (event) {
    var langBtn = event.target.closest("[data-lang-option]");
    if (!langBtn) return;
    applyLanguage(langBtn.getAttribute("data-lang-option"));
  });

  document.addEventListener("click", function (event) {
    var themeBtn = event.target.closest("[data-theme-option]");
    if (!themeBtn) return;
    applyTheme(themeBtn.getAttribute("data-theme-option"));
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

  applyTheme(currentTheme);
  applyLanguage(currentLang);
})();
