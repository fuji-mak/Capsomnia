(function () {
  "use strict";

  var translations = {
    en: {
      title: "Capsomnia — Caps Lock as a physical keep-awake switch for macOS",
      description:
        "Capsomnia turns Caps Lock into a physical keep-awake switch for closed-lid MacBook background work. Run Codex, Claude Code, SSH sessions, builds, and unattended scripts without sleep.",
      skipLink: "Skip to content",
      mainNavigationLabel: "Main navigation",
      languageLabel: "Language",
      downloadSectionLabel: "Download Capsomnia",
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
      linkSecurityTitle: "Security policy",
      linkSecuritySub: "Reporting &amp; model",
      footerCatch: "Give Caps Lock a real job"
    },
    ja: {
      title: "Capsomnia — Caps LockをMacの物理スリープ防止スイッチに",
      description:
        "CapsomniaはCaps Lockを、蓋を閉じたMacBookでも作業を止めないための物理スイッチに変えるmacOSアプリです。Codex、Claude Code、SSH、ビルド、ダウンロード、放置スクリプト向け。",
      skipLink: "本文へ移動",
      mainNavigationLabel: "メインナビゲーション",
      languageLabel: "言語",
      downloadSectionLabel: "Capsomniaをダウンロード",
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
      linkSecurityTitle: "セキュリティポリシー",
      linkSecuritySub: "報告方法と安全性モデル",
      footerCatch: "Macの最も無駄なキーに最高の仕事を与える"
    },
    "zh-Hans": {
      title: "Capsomnia — 把 Caps Lock 变成 macOS 实体防休眠开关",
      description:
        "Capsomnia 可将 Caps Lock 变成实体防休眠开关，让 MacBook 合盖后仍能继续运行后台任务。适用于 Codex、Claude Code、SSH 会话、构建、下载和无人值守脚本。",
      skipLink: "跳转到正文",
      mainNavigationLabel: "主导航",
      languageLabel: "语言",
      downloadSectionLabel: "下载 Capsomnia",
      navUses: "使用场景",
      navFeatures: "功能",
      navSecurity: "安全性",
      heroTitle: '让 Caps Lock<br><span class="catch-accent">真正派上用场</span>',
      heroSub:
        "<strong>把 Caps Lock 变成实体防休眠开关。</strong>开启它，合上屏幕，让后台任务继续运行。",
      downloadCta: "下载",
      stripLabel: "工作原理",
      stripOnTitle: "Caps Lock 开启",
      stripOnSub: "运行 <code>pmset -a disablesleep 1</code>，停用系统睡眠。",
      stripOffTitle: "Caps Lock 关闭",
      stripOffSub: "运行 <code>pmset -a disablesleep 0</code>，恢复正常睡眠。",
      previewLabel: "Capsomnia 应用预览",
      previewAlt: "Capsomnia 设置窗口",
      previewSrc: "app-preview-en.png",
      previewWidth: "800",
      previewHeight: "1038",
      usesTitle: "为 AI 智能体准备的实体开关",
      usesLede:
        "开启 Caps Lock，合上屏幕，让耗时较长的本地任务继续运行。Capsomnia 会让 MacBook 保持唤醒，直到你关闭 Caps Lock。键盘上的 Caps Lock 指示灯会直观显示防休眠状态。",
      cardAgentsTitle: "AI 智能体",
      cardAgentsBody: "合盖后继续运行耗时较长的 Codex 或 Claude Code 任务。",
      cardSshTitle: "SSH 会话",
      cardSshBody: "远程操作 Mac 时，避免设备在会话途中进入睡眠。",
      cardBuildsTitle: "构建与下载",
      cardBuildsBody: "让长时间编译和大型下载任务顺利完成。",
      cardScriptsTitle: "移动端连接",
      cardScriptsBody: "保持 Codex Mobile 等移动端会话连接，让任务不中断。",
      featuresEyebrow: "功能",
      featuresTitle: "合上屏幕，Mac 仍可继续工作",
      featuresLede:
        "Capsomnia 是一款小巧的 Mac 应用，专注于合盖后继续运行任务、通过实体指示灯显示状态，以及透明的开源设计。",
      featureClosedKicker: "合盖运行",
      featureClosedTitle: "合盖后任务继续运行",
      featureClosedBody:
        "开启 Caps Lock 并合上 MacBook，本地任务仍会继续运行。在已启用远程登录且网络可用时，你也可以继续通过 SSH 访问 Mac。",
      featureLedKicker: "实体状态",
      featureLedTitle: "Caps Lock 指示灯显示状态",
      featureLedBody:
        "指示灯亮起时，防休眠功能已开启。无需显示菜单栏图标，也能直接从键盘确认状态。",
      featureOssKicker: "开源",
      featureOssTitle: "完全免费，开源透明",
      featureOssBody:
        "项目采用 MIT 许可证。安装前，你可以检查源代码、软件包安装脚本、辅助程序命令和安全模型。",
      securityTitle: "安全模型",
      securityLede:
        "菜单栏应用以当前用户身份运行，绝不会以 root 身份运行。更改系统睡眠设置需要提升权限，因此 Capsomnia 通过免密码 <code>sudo</code> 调用一个功能固定、由 root 所有的小型辅助程序。",
      securityOfflineLabel: "隐私",
      securityOfflineNetwork: "无网络请求",
      securityOfflineTelemetry: "无遥测",
      securityOfflineAccounts: "无需账户",
      securityInvokeTitle: "应用只能调用",
      securityInvokeBody: "软件包中的应用、辅助程序和系统 LaunchAgent 均由 root 所有。sudoers 规则仅允许执行以下三个完全匹配的命令。",
      securityHelperTitle: "辅助程序只会运行",
      securityHelperBody: "仅接受 <code>on</code>、<code>off</code> 和 <code>display-sleep</code>，不会接受其他参数。",
      securityInputTitle: "无需输入监控权限",
      securityInputBody: "Capsomnia 不会读取键盘事件，只会每 250 毫秒检查一次本机 Caps Lock 状态。",
      securityBackgroundTitle: "后台项目提示",
      securityBackgroundBody:
        "macOS 可能会将“Taketo Fujimaki”显示为后台项目。这是用于在登录时启动 Capsomnia，并在崩溃后重新启动应用的 LaunchAgent。",
      securityReq:
        "退出应用会恢复正常睡眠。停用睡眠并合盖使用可能会增加发热和耗电量，请留意通风、电源和运行时长。",
      linksTitle: "链接",
      linkRepoTitle: "GitHub 仓库",
      linkRepoSub: "源代码、Issue 和 Release",
      linkReadmeSub: "英文文档",
      linkReadmeJaSub: "日文文档",
      linkSecurityTitle: "安全策略",
      linkSecuritySub: "报告方式与安全模型",
      footerCatch: "让 Caps Lock 真正派上用场"
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
    return lang === "ja" || lang === "en" || lang === "zh-Hans" ? lang : null;
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
