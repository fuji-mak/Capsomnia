# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia 图标" width="128" height="128">
</p>

<p align="center">
  <a href="README.md"><img alt="English README" src="https://img.shields.io/badge/README-EN-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="README.ja.md"><img alt="日本語 README" src="https://img.shields.io/badge/README-JA-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://fuji-mak.github.io/Capsomnia/"><img alt="官网" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT 许可证" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

当前版本：`1.5.0`

[English README](README.md) · [日本語 README](README.ja.md) · [安全说明](SECURITY.zh-CN.md)

## 社区改进版

这是 [fuji-mak/Capsomnia](https://github.com/fuji-mak/Capsomnia) 的社区改进版，保留原项目版权与 MIT 许可证。

主要升级：原生菜单栏、直接“合盖时保持开机状态”开关、简中/英文/日文、可靠的合盖关屏，以及 Codex/Claude 任务完成后自动睡眠。设计上只突出最常用的开关，其余选项使用原生对勾；实心圆和空心圆表示状态，红点只表示错误。

**合上 Mac，AI 继续跑；任务结束，Mac 自己睡。** 自动睡眠默认开启。只有确认已经合盖、全部 Codex/Claude 任务都停止后，才会静默等待 5 分钟再睡眠；期间可以从菜单取消本次睡眠。

Capsomnia 是一款 macOS 菜单栏应用：打开“合盖时保持开机状态”后，即使 MacBook 合盖，本机任务也会**持续运行**。

需要让任务继续时打开“合盖时保持开机状态”；需要交还给系统时关闭它，Mac 将恢复**正常休眠**并遵循你的系统设置。

它适合 AI 智能体、远程访问、SSH、构建、下载和其他耗时的本机任务。

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="已点亮的 Caps Lock 指示灯" width="560">
</p>

<p align="center">
  <em>菜单栏黄绿色状态亮起时，任务会持续运行。</em>
</p>

## 快速开始

要求：

- 搭载 macOS 14 或更高版本的 Apple 芯片 Mac
- 安装时可使用管理员权限

通过本地构建的安装包安装：

1. 在本机完成构建，或取得与本定制源码一同交付的 `Capsomnia-1.5.0-cn-unsigned.pkg`。
2. 打开安装包，并按照安装器提示完成安装；如 macOS 提示来源未验证，请按你的安全策略确认来源后继续。

本定制版 1.5.0 只能交付本地构建的未签名安装包（payload 使用 ad-hoc 签名）或源码，未使用原作者的 Developer ID，也未经 Apple 公证。它会将 `Capsomnia.app` 安装到 `/Applications`，安装原生特权 helper、受限的 sudoers 规则和 LaunchAgent。安装后 Capsomnia 会自动打开；之后每次登录也会自动启动。

原官方 1.0.0 发布包使用 Developer ID 签名并经过 Apple 公证；该发布保证不适用于此定制版。

安装包的构建与安装逻辑可在 [`scripts/build-pkg.sh`](scripts/build-pkg.sh) 和 [`scripts/notarize-pkg.sh`](scripts/notarize-pkg.sh) 查看。

## 从源码安装

开发者也可以从源码安装，需要 Swift 6 工具链：

进入本定制版源码目录后运行：

```sh
./scripts/install.sh
```

源码安装器会在本机构建 `Capsomnia.app`，放到 `~/Applications/`，并安装相同的 helper、sudoers 规则和用户级 LaunchAgent。

## 使用方式

- **“合盖时保持开机状态”打开：持续运行。** 系统睡眠被禁止；即使合上 MacBook，AI 智能体和其他本机任务也会继续执行。
- **“合盖时保持开机状态”关闭：正常休眠。** Capsomnia 恢复系统原有的睡眠行为，并遵循 macOS 的设置。
- **持续运行时合盖：** 任务继续执行；如果启用了对应设置，应用会在合盖期间持续让显示器保持休眠，避免被外接设备再次唤醒。
- **Codex/Claude 任务结束：** 仅在确认合盖、所有会话和子智能体都停止后，静默等待 5 分钟再睡眠；“取消本次自动睡眠”只取消这一次。
- **等待确认或状态不完整：** 如果 Hook 无法可靠证明任务已经结束，Capsomnia 会继续保持唤醒，不会仅凭超时冒险睡眠。
- **低电量保护：** 未接电源、确认合盖且电量不高于 10% 时，会优先恢复正常睡眠并让 Mac 睡眠，避免直接耗尽电池。
- **菜单栏状态：** 灰色空心圆圈表示持续运行，灰色实心圆点表示正常休眠，红点表示设置失败；鼠标移入可查看文字状态。
- **菜单栏菜单：** 单击状态图标即可切换“合盖时保持开机状态”“Codex/Claude任务完成后自动睡眠”“合盖自动关闭外接显示器”“开机自动启动 Capsomnia”和 Language；最底部可以退出 Capsomnia。
- **退出应用：** 正常退出会恢复正常休眠。

Capsomnia 适合长时间本机任务、AI 编程智能体、SSH 会话、构建、下载和无人值守脚本。

## 设置

Capsomnia 没有独立设置窗口。单击菜单栏状态图标即可设置：

- 合盖时是否保持开机状态
- Codex/Claude 任务完成后是否自动睡眠（默认开启）
- 合盖时是否自动关闭外接显示器
- 是否在开机后自动启动 Capsomnia
- 使用简体中文、English 或日本語

菜单栏图标始终显示，因为它是应用的唯一入口。

无需授予“输入监控”权限。Capsomnia 不读取键盘事件；如果你曾为旧版本授予过输入监控权限，可以在“系统设置”中关闭它。

Codex 的生命周期 Hook 属于非托管 Hook。首次启用后，请在 Codex 中使用 `/hooks` 审阅并信任 Capsomnia 添加的命令；未完成信任时，Capsomnia 会保持安全状态，不会根据不完整事件主动睡眠。

安装包安装后，可从 `/Applications/Capsomnia.app` 启动；源码安装后，可从 `~/Applications/Capsomnia.app` 启动。日常设置直接使用始终显示的菜单栏图标。

## 为什么不是 `caffeinate`

`caffeinate` 很适合在 Mac 打开时防止闲置休眠。但合上 MacBook 的盖子是另一种场景：普通的 `caffeinate` assertion 并不能可靠地保证本机任务持续运行。

Capsomnia 让合盖后的任务像电脑保持打开时一样继续执行，菜单栏状态会显示当前是“持续运行”还是“正常休眠”。

## 安全与使用注意

- 合盖持续运行会增加发热和电池消耗。无人看管时，请注意通风、电源和预计运行时间。
- Capsomnia 是手动开关：“合盖时保持开机状态”打开表示“持续运行”，关闭表示“正常休眠”。
- 菜单栏应用本身不以 root 身份运行。更改系统睡眠设置时，它仅通过免密码 `sudo` 调用固定的原生 helper。
- 应用和 helper 的所有者为 `root:wheel`；LaunchAgent 只安装到当前用户目录，不会自动作用于其他账户。开启时应用会立即验证真实的 `SleepDisabled` 状态，系统唤醒时再次验证，并每 60 秒进行一次兜底检查；关闭主开关后停止定时检查。
- 如果 helper 无法应用设置、状态无法验证或设置发生漂移，菜单栏会显示红色错误状态，并在 5 秒后重试。简体中文提示为“未能更新睡眠设置，正在重试”。
- Capsomnia 不发起网络请求、不收集遥测数据，也不需要账号。
- AI 工具接入只修改当前用户的本地 Codex/Claude 配置。Codex 原有完成通知会被保留并继续执行；卸载时只移除 Capsomnia 自己添加的接入项。

应用只能调用：

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

sudoers 规则仅允许上面四条精确命令。helper 只接受 `on`、`off`、`display-sleep` 和 `sleep-now`，并且只会调用：

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
/usr/bin/pmset sleepnow
```

## 更新

本定制版安装包：请在本机构建，或使用为你本地构建的安装包。不要将官方 GitHub Releases 的签名与公证状态视为本定制版的发布状态。

源码安装：在已有的源码目录中执行：

```sh
cd Capsomnia
git pull
./scripts/install.sh
```

安装脚本会以当前版本覆盖 app bundle、helper、sudoers 规则和 LaunchAgent。

## 日志与排障

日志位于：

```text
~/Library/Logs/Capsomnia/
```

`capsomnia.log` 超过 1 MiB 时会轮转为一个 `capsomnia.log.old`；只保留最近的一份旧日志，避免异常状态长期占用磁盘。

检查当前是否禁止睡眠：

```sh
pmset -g | grep SleepDisabled
```

手动恢复正常休眠：

```sh
sudo pmset -a disablesleep 0
```

重启 LaunchAgent：

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
```

安装包和源码安装都使用当前用户的 `$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist`。

Capsomnia 的 LaunchAgent 会在应用崩溃或其他非正常退出后重启应用。启动时应用会读取“合盖时保持开机状态”设置并重新应用相应的睡眠状态；正常选择“退出”不会触发重启。

检查 helper 权限：

```sh
sudo -n -l /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off \
  /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep \
  /Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

如权限检查失败，请再次运行 `./scripts/install.sh`。“合盖时保持开机状态”改变后，Capsomnia 会立即应用并核对真实的系统睡眠状态。

## 卸载

安装包安装：

```sh
/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

源码安装：

```sh
~/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

从源码目录执行时，等价命令为：

```sh
./scripts/uninstall.sh
```

卸载器会卸载 LaunchAgent、停止 Capsomnia、从 `/Applications` 或 `~/Applications` 删除 `Capsomnia.app`，移除 helper 和 sudoers 规则，并恢复正常休眠。可能需要管理员认证。

## 项目状态

Capsomnia 1.5.0 采用单一原生菜单栏入口，并增加多任务合盖收工与低电量保护；自动睡眠和其他次要功能继续使用原生对勾。发布历史请查看 [CHANGELOG.md](CHANGELOG.md)，安全模型和漏洞报告方式请查看 [简体中文安全说明](SECURITY.zh-CN.md)。

## 许可证

MIT
