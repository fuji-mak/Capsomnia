# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia 图标" width="128" height="128">
</p>

<p align="center">
  <a href="README.en.md">English</a> · <a href="README.ja.md">日本語</a>
</p>

## 合上 Mac，AI 继续跑。任务结束，Mac 自己睡。

Codex、Claude Code 跑长任务，不该逼你守着电脑，也不该让 Mac 白白亮一整夜。

Capsomnia 让 MacBook 合盖后继续工作；Codex 或 Claude 任务完成后，再让 Mac 自动睡眠。人可以先走，机器知道什么时候收工。

## 它解决什么

- AI 智能体、SSH、构建、下载，合盖后不中断
- 可在合盖期间自动关闭外接显示器
- 菜单栏一键开关，不再依赖 Caps Lock
- Codex/Claude 任务完成后自动睡眠，默认开启，30 秒内可取消
- 不联网、不收集数据、不需要账号

## 这个版本改了什么

- 用原生菜单栏替代原来的设置窗口
- 最常用的“合盖时保持开机状态”做成主开关，次要设置使用原生对勾
- 支持简体中文、English、日本語
- 修复外接显示器在合盖后被再次唤醒的问题
- 加强安装、卸载、权限和运行状态校验
- 自动识别并接入 Codex/Claude，同时保留已有通知和钩子

菜单栏图标很简单：空心圆表示持续运行，实心圆表示正常休眠，红点表示设置失败。

## 安装

需要 Apple 芯片 Mac、macOS 14 或更高版本，以及 Swift 6 工具链。

```sh
git clone https://github.com/usernameup/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

安装过程需要管理员权限。当前社区版提供源码安装和本地构建的未签名安装包，不使用原作者的 Developer ID 或 Apple 公证。

## 使用提醒

合盖持续运行会增加发热和耗电。长时间运行时请注意通风、电源和任务备份；用完后关闭“合盖时保持开机状态”，确认 Mac 已恢复正常休眠。

## 来源与许可

本项目基于 [fuji-mak/Capsomnia](https://github.com/fuji-mak/Capsomnia) 改进，保留原作者版权，并继续使用 [MIT License](LICENSE)。

当前版本：`1.4.0` · [升级记录](CHANGELOG.md) · [安全说明](SECURITY.zh-CN.md)
