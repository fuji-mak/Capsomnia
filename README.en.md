# Capsomnia — English

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia icon" width="128" height="128">
</p>

<p align="center">
  <a href="README.zh-CN.md"><img alt="简体中文 README" src="https://img.shields.io/badge/README-ZH--CN-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="README.ja.md"><img alt="日本語 README" src="https://img.shields.io/badge/README-JA-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://fuji-mak.github.io/Capsomnia/"><img alt="Website" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

Current version: `1.5.0`

[简体中文 README](README.zh-CN.md) · [日本語 README](README.ja.md) · [Security](SECURITY.md)

## Community Edition

This is a community edition of [fuji-mak/Capsomnia](https://github.com/fuji-mak/Capsomnia). It keeps the original copyright and MIT license.

Main changes: a native menu-bar UI, a direct “Keep Mac Awake When Lid Closes” switch, Chinese/English/Japanese, reliable display sleep while the lid is closed, and automatic sleep after Codex or Claude finishes a task. The main switch stays prominent; secondary options use native checkmarks. Filled and hollow circles show state, while red is reserved for errors.

**Close the Mac. Let AI keep working. When every task is done, the Mac sleeps itself.** Automatic sleep is enabled by default. After the lid is confirmed closed and every recognized Codex/Claude session and subagent has stopped, Capsomnia waits for a five-minute quiet period before sleeping.

Customization note: this 1.5.0 variant is delivered only as source or a locally built unsigned package with ad-hoc-signed payloads. It does not use the original author's Developer ID or Apple notarization; the official 1.0.0 release's signing and notarization do not apply to this variant.

Capsomnia is a small macOS menu bar app that keeps local work running while a MacBook lid is closed.

Turn “Keep Mac Awake When Lid Closes” on when local work should continue. Turn it off when you want normal sleep behavior back.

It is useful for AI agents, mobile access, and other long-running or remote work.

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="Caps Lock light on" width="560">
</p>

<p align="center">
  <em>The lime menu bar status indicates that keep-running mode is active.</em>
</p>

## Quick Start

Requirements:

- Apple silicon Mac with macOS 14 or later
- Administrator access during installation

Install a locally built package:

1. Build the package locally or obtain `Capsomnia-1.5.0-cn-unsigned.pkg` delivered with this customized source.
2. Open the package and follow the installer, confirming its source according to your security policy.

This customization's package is unsigned and uses ad-hoc signatures for its payload. It installs `Capsomnia.app` in `/Applications`, the native privileged sleep-control helper, a narrow sudoers rule, and the LaunchAgent. The original official 1.0.0 package was Developer ID-signed and Apple-notarized; those assurances do not apply to this customization.

The package build and install scripts are public in [`scripts/build-pkg.sh`](scripts/build-pkg.sh) and [`scripts/notarize-pkg.sh`](scripts/notarize-pkg.sh).

## Build From Source

Developer source install still works and requires a Swift 6 toolchain:

From this customized source directory, run:

```sh
./scripts/install.sh
```

The source installer builds `Capsomnia.app` locally, places it in `~/Applications/`, installs the same helper and sudoers rule, and starts a user LaunchAgent.

## What It Does

- Enabled on: keeps AI agents and other work from being interrupted when the MacBook lid is closed.
- Enabled off: restores normal sleep behavior.
- Lid closed while enabled: keeps work running and, when selected, repeatedly keeps displays asleep so external input cannot leave them awake.
- Codex or Claude tasks finished: only after the lid is confirmed closed and every recognized session and subagent has stopped, waits five minutes and then puts the Mac to sleep. Cancel affects only that pending sleep.
- Permission or incomplete lifecycle state: stays awake unless the hooks can reliably prove that work has ended. It never guesses from a timeout while a task may still be running.
- Low-battery protection: while unplugged, enabled, and confirmed closed, a battery level of 10% or lower restores normal sleep and sleeps the Mac to avoid draining it completely.
- Quitting the app restores normal sleep behavior.

Capsomnia is useful for long-running local jobs, AI coding agents, SSH sessions, builds, downloads, and unattended scripts.

## Settings

Capsomnia has no standalone settings window. Click its permanent status item to choose:

- whether keep-running mode is enabled
- whether to sleep automatically after Codex/Claude tasks finish (on by default)
- whether to turn the display off when the lid closes
- whether to open Capsomnia at login
- Simplified Chinese, English, or Japanese

The same native menu includes a bottom Quit command. The status item remains visible because it is the app's only entry point.

No Input Monitoring permission is required. Capsomnia does not read keyboard events. If you enabled Input Monitoring for an earlier version, you can disable it in System Settings.

Codex lifecycle hooks remain subject to Codex's normal review and trust flow. After enabling the integration, use `/hooks` in Codex to review and trust Capsomnia's command. Until trustworthy lifecycle events arrive, Capsomnia fails closed and does not initiate task-completion sleep.

Launch Capsomnia from `/Applications/Capsomnia.app` after package installation or from `~/Applications/Capsomnia.app` after source installation. Use its permanent menu bar item for everyday settings.

## Why Not `caffeinate`?

`caffeinate` is useful for preventing idle sleep while your Mac is open. Closing a MacBook lid is different: normal `caffeinate` assertions do not reliably keep local jobs running in closed-lid use.

Capsomnia keeps work running in closed-lid use the same way it would while the lid is open. The menu bar tooltip shows the actual current state.

## Safety Notes

- Sleep-disabled closed-lid use can increase heat and battery drain.
- Use good judgment for airflow, power, and runtime when leaving your Mac unattended.
- Capsomnia is a manual switch: Enabled on means "keep running"; Enabled off means "normal sleep behavior".

## Update

For this customization, build a package locally or use the source installer. Do not treat the signing and notarization of an official GitHub Release as applying to this variant.

For source installs, update from an existing clone:

```sh
cd Capsomnia
git pull
./scripts/install.sh
```

The install script overwrites the app bundle, helper, sudoers rule, and LaunchAgent with the current version.

## Uninstall

For package installs:

```sh
/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

For source installs:

```sh
~/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

From a source clone, this is equivalent:

```sh
./scripts/uninstall.sh
```

The uninstaller unloads the LaunchAgent, stops Capsomnia, removes `Capsomnia.app` from `/Applications` or `~/Applications`, removes the helper, removes the sudoers rule, and restores normal sleep behavior. Administrator authentication may be required.

## Security Model

Capsomnia's menu bar app does not run as root. System sleep settings require elevated privileges, so Capsomnia uses a small fixed native helper through passwordless `sudo`. The helper is a compiled executable and does not invoke a shell or load shell startup files.

Package-installed app files and the helper are owned by `root:wheel`. The LaunchAgent is installed only for the current user, so other accounts are not started or configured automatically. Local unsigned builds seal the app and helper with ad-hoc signatures; only a separately configured official distribution build signs both with a Developer ID. While keep-awake mode is on, Capsomnia verifies the actual `SleepDisabled` state after every change, when displays wake, and once every 60 seconds as a fallback. Periodic checks stop when the main switch is off. If the helper cannot apply a change, the state cannot be verified, or the setting drifts, the menu bar dot turns red and Capsomnia retries after five seconds instead of showing the requested state as active.

Capsomnia itself does not make network requests, collect telemetry, or require an account.

Capsomnia does not request Input Monitoring or read keyboard events.

macOS may report that a background item was added after installation. This is the LaunchAgent that starts Capsomnia at login and restarts it after crashes. Disabling it can stop automatic startup and crash recovery.

If Capsomnia is force-killed while crash recovery is disabled or unavailable, the last system sleep setting can remain active. Use the manual recovery command below to restore normal sleep behavior.

The app can only invoke:

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

The sudoers rule is limited to those four exact commands. The helper only accepts `on`, `off`, `display-sleep`, and `sleep-now`, and only calls:

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
/usr/bin/pmset sleepnow
```

## Logs and Troubleshooting

Logs are written to:

```text
~/Library/Logs/Capsomnia/
```

Check whether sleep is disabled:

```sh
pmset -g | grep SleepDisabled
```

Restore normal sleep manually:

```sh
sudo pmset -a disablesleep 0
```

Restart the LaunchAgent:

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
```

Package and source installs both use `$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist`.

Capsomnia's LaunchAgent restarts the app after a crash or other unsuccessful exit. On startup, Capsomnia reads the Enabled preference and reapplies the matching sleep setting. Normal Quit still exits cleanly and does not restart the app.

Check the helper permissions:

```sh
sudo -n -l /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off \
  /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep \
  /Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

If the helper permission check fails, run `./scripts/install.sh` again. Capsomnia applies and verifies the actual system sleep state immediately after Enabled changes.

## Project Status

Capsomnia 1.4.0 uses one native status-bar menu, keeps the prominent switch only for Enabled, presents automatic sleep and other secondary options as native checkmarks, and uses quiet gray status symbols. See [CHANGELOG.md](CHANGELOG.md) for release history and [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

MIT
