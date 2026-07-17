# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia 图标" width="128" height="128">
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia.pkg"><img alt="下载Capsomnia.pkg" src="https://img.shields.io/badge/Download-Capsomnia.pkg-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://capsomnia.com/zh-hans/"><img alt="网站" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT 许可证" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

当前版本：`1.0.2`

[English README](README.md) · [日本語 README](README.ja.md)

本文是英文README的简体中文翻译。如有差异，请以[英文README](README.md)为准。

Capsomnia是一款小巧的macOS菜单栏应用，可将Caps Lock变成MacBook合盖工作时的实体防休眠开关。

需要让本地任务继续运行时，请开启Caps Lock。需要恢复正常睡眠行为时，请关闭Caps Lock。

它适用于AI智能体、移动端访问，以及其他耗时较长或需要远程操作的任务。

Capsomnia本身不会发起网络请求、收集遥测数据，也不需要账户。

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="Caps Lock 指示灯亮起" width="560">
</p>

<p align="center">
  <em>当这盏小灯亮起时，你的Mac将保持唤醒。</em>
</p>

## 快速开始

要求：

- 搭载Apple芯片、运行macOS 14或更高版本的Mac
- 安装时拥有管理员权限

安装已签名的软件包：

1. 从[GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest)下载`Capsomnia.pkg`。
2. 打开软件包并按照安装器提示操作。

发布的软件包使用Developer ID签名，并已通过Apple公证。软件包会将`Capsomnia.app`安装到`/Applications`，安装已签名的原生特权休眠控制辅助程序，添加权限范围严格受限的sudoers规则，并启动LaunchAgent。安装完成后Capsomnia会自动打开，之后会在登录时自动启动。

软件包的构建与公证脚本公开在[`scripts/build-pkg.sh`](scripts/build-pkg.sh)和[`scripts/notarize-pkg.sh`](scripts/notarize-pkg.sh)中。

## 从源代码构建

开发者仍可从源代码安装，需要Swift 6工具链：

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

源代码安装器会在本地构建`Capsomnia.app`，将其放入`~/Applications/`，安装同样的辅助程序和sudoers规则，并启动用户LaunchAgent。

## 功能

- Caps Lock开启：MacBook合盖后，AI智能体和其他任务仍可继续运行。也可以继续通过Codex Mobile等工具远程操作。Caps Lock指示灯会直观显示当前状态。
- Caps Lock关闭：恢复正常睡眠行为。
- Caps Lock开启时合盖：仅在未连接外接显示器时关闭显示屏，后台任务继续运行。
- 退出应用：恢复正常睡眠行为。

Capsomnia适合长时间运行的本地任务、AI编程智能体、SSH会话、构建、下载和无人值守脚本。

## 使用注意事项

- 请确保通风良好，并使用稳定的电源。
- 在防止睡眠的状态下合盖使用，可能会增加发热和电池消耗。
- 请勿将Capsomnia作为关键任务的唯一保障或备份替代方案。
- 使用完毕后，请关闭Caps Lock并确认系统已恢复正常睡眠行为。
- 请自行承担使用风险。不保证适用于所有Mac、macOS版本或运行环境。

## 设置

首次启动时，Capsomnia会说明Caps Lock开关的工作方式，并允许你选择：

- 是否显示菜单栏状态圆点
- 未连接外接显示器时，合盖后是否关闭显示屏
- 是否在登录时启动Capsomnia
- 使用英语、日语或简体中文

之后可以再次打开Capsomnia修改相同设置。

无需授予“输入监控”权限。Capsomnia每250毫秒只检查一次本机Caps Lock状态。如果你曾为旧版本启用“输入监控”，可以在“系统设置”中关闭该权限。

通过软件包安装后，可以从`/Applications/Capsomnia.app`打开Capsomnia；从源代码安装后，可以从`~/Applications/Capsomnia.app`打开；菜单栏项目可见时，也可以从菜单栏打开。

## 为什么不使用`caffeinate`？

`caffeinate`适合在Mac保持打开时防止空闲睡眠。MacBook合盖则是另一种情况：普通的`caffeinate`断言无法可靠保证本地任务在合盖后继续运行。

Capsomnia可以让任务在合盖后像开盖时一样继续运行。黄绿色的Caps Lock指示灯会直观显示该状态。

## 更新

如果通过软件包安装，请从[GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest)下载并运行最新软件包。

如果从源代码安装，可以在现有克隆中更新：

```sh
cd Capsomnia
git pull
./scripts/install.sh
```

安装脚本会用当前版本覆盖应用程序包、辅助程序、sudoers规则和LaunchAgent。

## 卸载

通过软件包安装时：

```sh
/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

从源代码安装时：

```sh
~/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

也可以在源代码克隆目录中执行等效命令：

```sh
./scripts/uninstall.sh
```

卸载程序会卸载LaunchAgent、停止Capsomnia、删除`/Applications`或`~/Applications`中的`Capsomnia.app`、删除辅助程序和sudoers规则，并恢复正常睡眠行为。过程中可能需要管理员认证。

## 安全模型

Capsomnia的菜单栏应用不会以root身份运行。修改系统睡眠设置需要提升权限，因此Capsomnia通过免密码`sudo`调用一个功能固定的小型原生辅助程序。该辅助程序是已编译的可执行文件，不会调用shell，也不会加载shell启动文件。

通过软件包安装的应用文件、辅助程序和系统LaunchAgent均归`root:wheel`所有。软件包中的辅助程序也使用与应用相同的Developer ID签名。Capsomnia会在每次切换后以及之后每10秒检查一次实际的`SleepDisabled`状态。如果辅助程序无法应用更改、状态无法验证，或设置发生漂移，菜单栏圆点会变为红色，Capsomnia会在5秒后重试，而不会将请求的状态错误地显示为已启用。即使平时隐藏菜单栏图标，发生错误时也会暂时显示红色圆点。

Capsomnia不会请求“输入监控”权限，也不会读取键盘事件。它每250毫秒只检查一次本机Caps Lock状态，并设置定时器容差，以便macOS合并唤醒。

对于现有的缓存注册，安装后macOS仍可能将后台项目显示为“Taketo Fujimaki”而不是“Capsomnia”。这是用于在登录时启动Capsomnia并在崩溃后重新启动应用的LaunchAgent。禁用它可能会导致自动启动和崩溃恢复失效。

如果在崩溃恢复被禁用或不可用时强制结束Capsomnia，最后一次系统睡眠设置可能会保持生效。请使用下面的手动恢复命令恢复正常睡眠行为。

应用只能调用：

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

sudoers规则仅允许以上三个完全匹配的命令。辅助程序只接受`on`、`off`和`display-sleep`，内部只调用：

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
```

## 日志与故障排除

日志保存在：

```text
~/Library/Logs/Capsomnia/
```

检查是否已禁用睡眠：

```sh
pmset -g | grep SleepDisabled
```

手动恢复正常睡眠：

```sh
sudo pmset -a disablesleep 0
```

重新启动LaunchAgent：

```sh
launchctl bootout "gui/$(id -u)" /Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist
launchctl bootstrap "gui/$(id -u)" /Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist
```

从源代码安装时，请改用`$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist`。

Capsomnia的LaunchAgent只会在应用崩溃或其他非正常退出后重新启动应用。启动时，Capsomnia会读取当前Caps Lock状态，并重新应用对应的睡眠设置。通过“退出”正常关闭应用后，不会重新启动。

检查辅助程序权限：

```sh
sudo -n -l /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off \
  /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

如果辅助程序权限检查失败，请再次运行`./scripts/install.sh`。Capsomnia每250毫秒检查一次Caps Lock状态，因此从物理指示灯变化到菜单栏圆点更新，最多可能延迟约0.25秒。

## 项目状态

Capsomnia 1.0.0是首个正式稳定版本。发布历史请参阅[CHANGELOG.md](CHANGELOG.md)，漏洞报告方式请参阅[SECURITY.md](SECURITY.md)。

## 许可证

MIT
