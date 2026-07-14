# Capsomnia 安全说明

## 这款应用会获得什么权限

Capsomnia 的界面程序始终以当前登录用户运行，不会以 root 身份运行，也不需要“输入监控”权限。它不读取或记录按键内容。

为了切换系统睡眠状态，安装器会放置一个 root 所有的固定 helper：

```text
/Library/PrivilegedHelperTools/capsomnia-pmset
```

当前用户只能免密码调用下面四个完整命令：

```text
/Library/PrivilegedHelperTools/capsomnia-pmset on
/Library/PrivilegedHelperTools/capsomnia-pmset off
/Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
/Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

helper 不启动 shell，只接受 `on`、`off`、`display-sleep` 和 `sleep-now`，内部只能执行：

```text
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
/usr/bin/pmset sleepnow
```

## 隐私与联网

- 应用本身不联网。
- 不收集使用数据或遥测信息。
- 不需要账户。
- 不访问钥匙串；除合并 Codex/Claude 的本地完成通知配置外，不读取任务文件。
- Codex/Claude 接入只合并本地完成通知配置，不保存提示词或任务内容；卸载时只撤销 Capsomnia 自己添加的项目。写入时使用独占侧车锁、`NSFileCoordinator`、逐字节变更检查和原子替换；如果要手动编辑这些配置，请先关闭该选项，避免与不遵守建议锁的其他进程同时写入。
- 本地日志只记录启动、设置切换和错误状态；1.1.0 起会自动轮转，避免无限增长。

## 安装失败时会怎样

1.1.0 起，安装器会在修改系统文件前先确认管理员权限。若安装中途失败，会撤销本次创建的 sudoers 规则和后台启动服务，并尝试恢复正常休眠。安装成功后还会验证 LaunchAgent 是否真的载入，不再把后台启动失败当作成功。

## 异常恢复

如果菜单栏显示红色状态，表示系统睡眠设置没有按预期生效，应用会自动重试。需要立即恢复时，可关闭设置页顶部的“启用”，或退出 Capsomnia。

极端情况下可以在终端执行：

```sh
sudo pmset -a disablesleep 0
```

卸载脚本会先恢复正常休眠，再删除应用、helper、LaunchAgent 和 sudoers 规则。

## 报告安全问题

涉及权限、安装器、sudoers、helper 或睡眠状态的问题，请不要先公开漏洞细节。可通过原项目维护者的 X 账号 `@tf_makimaki` 联系，并附上 macOS 版本、复现步骤和受影响组件。
