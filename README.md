# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia icon" width="128" height="128">
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia.pkg"><img alt="Download Capsomnia.pkg" src="https://img.shields.io/badge/Download-Capsomnia.pkg-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://capsomnia.com/"><img alt="Website" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

Current version: `2.0.2`

[日本語 README](README.ja.md) · [简体中文 README](README.zh-Hans.md) · [한국어 README](README.ko.md)

Capsomnia is a small macOS menu bar app that turns Caps Lock into a physical keep-awake switch for closed-lid MacBook work.

Turn Caps Lock on when local work should keep running. Turn Caps Lock off when you want normal sleep behavior back.

It is useful for AI agents, mobile access, and other long-running or remote work.

Capsomnia itself does not make network requests, collect telemetry, or require an account.

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="Caps Lock light on" width="560">
</p>

<p align="center">
  <em>When this tiny light is on, your Mac stays awake.</em>
</p>

## Quick Start

Requirements:

- Apple silicon Mac with macOS 14 or later
- Administrator access during installation

Install the signed package:

1. Download `Capsomnia.pkg` from [GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest).
2. Open the package and follow the installer.

Release packages are signed with Developer ID and notarized by Apple. The package installs `Capsomnia.app` in `/Applications`, installs the signed native privileged sleep-control helper, adds a narrow sudoers rule, and starts the LaunchAgent. Capsomnia opens after installation and starts automatically at login afterward.

The package build and install scripts are public in [`scripts/build-pkg.sh`](scripts/build-pkg.sh) and [`scripts/notarize-pkg.sh`](scripts/notarize-pkg.sh).

## Build From Source

Developer source install still works and requires a Swift 6 toolchain:

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

The source installer builds `Capsomnia.app` locally, places it in `~/Applications/`, installs the same helper and sudoers rule, and starts a user LaunchAgent.

## What It Does

- Prevent all-caps typing (optional): when Capsomnia is on, Caps Lock no longer forces uppercase input. Shift still types uppercase letters.
- Caps Lock on: keeps AI agents and other work from being interrupted when the MacBook lid is closed. Remote operation through tools such as Codex Mobile remains possible. The Caps Lock light physically shows the current state.
- Custom toggle shortcut: turn Capsomnia on or off with another key combination even if Caps Lock is assigned elsewhere. The green Caps Lock light continues to show the current state.
- Caps Lock off: restores normal sleep behavior.
- Lid closed while Capsomnia is on: puts the display to sleep only when no external display is connected, while work keeps running.
- Quitting the app restores normal sleep behavior.

Capsomnia is useful for long-running local jobs, AI coding agents, SSH sessions, builds, downloads, and unattended scripts.

## Usage Notes

- Ensure sufficient airflow and use a stable power source.
- Closed-lid use while sleep prevention is active may increase heat and battery consumption.
- Do not rely on Capsomnia for critical jobs or as a substitute for backups.
- Turn Caps Lock off after use and confirm that normal sleep behavior has returned.
- Use Capsomnia at your own risk. Compatibility is not guaranteed for every Mac, macOS version, or environment.

## Settings

On first launch, Capsomnia explains how the Caps Lock switch works and lets you choose:

- whether to show the menu bar dot
- whether to prevent all-caps typing while Capsomnia is on
- English, Japanese, Simplified Chinese, or Korean

"Turn display off when lid closes" and "Open at login" are enabled by default and do not appear in initial setup. Open Capsomnia again later to change all settings. Advanced Settings also lets you record a global shortcut that toggles Capsomnia through the real Caps Lock state. "Show menu bar icon" remains independent when "Prevent all-caps typing" is enabled. If the icon is hidden, a red dot appears temporarily when an error occurs.

macOS Accessibility permission is required only when "Prevent all-caps typing" is enabled. Capsomnia installs a local Core Graphics event filter that removes only the Caps Lock modifier from keyboard events; it does not store keyboard input or send it anywhere. If permission is missing or the filter stops, Capsomnia fails closed: sleep prevention is turned off, the menu bar dot turns red, and the app retries. When this setting is disabled, Accessibility permission is not required and Capsomnia only checks the local Caps Lock state every 250 milliseconds.

You can open Capsomnia from `/Applications/Capsomnia.app` after package installation, from `~/Applications/Capsomnia.app` after source installation, or from the menu bar item while it is visible.

## Why Not `caffeinate`?

`caffeinate` is useful for preventing idle sleep while your Mac is open. Closing a MacBook lid is different: normal `caffeinate` assertions do not reliably keep local jobs running in closed-lid use.

Capsomnia keeps work running in closed-lid use the same way it would while the lid is open. The yellow-green Caps Lock light makes that state visible.

## Update

For package installs, download and run the latest package from [GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest).

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

Package-installed app files, the helper, and the system LaunchAgent are owned by `root:wheel`. The packaged helper is also signed with the same Developer ID as the app. Capsomnia verifies the actual `SleepDisabled` state after every change and every ten seconds afterward. If the helper cannot apply a change, the state cannot be verified, or the setting drifts, the menu bar dot turns red and Capsomnia retries after five seconds instead of showing the requested state as active. The red error dot appears temporarily even if the menu bar icon is normally hidden.

When "Prevent all-caps typing" is disabled, Capsomnia does not request Input Monitoring or inspect keyboard events. When it is enabled, a local active Core Graphics event filter uses Accessibility permission only to remove `.maskAlphaShift` and suppress the Caps Lock modifier-change event. It does not log event contents, persist them, or send them over the network. Capsomnia still reads the physical Caps Lock state every 250 milliseconds to control sleep.

macOS may show "Taketo Fujimaki" instead of "Capsomnia" for an existing cached background-item registration. This is the LaunchAgent that starts Capsomnia at login and restarts it after crashes. Disabling it can stop automatic startup and crash recovery.

If Capsomnia is force-killed while crash recovery is disabled or unavailable, the last system sleep setting can remain active. Use the manual recovery command below to restore normal sleep behavior.

The app can only invoke:

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

The sudoers rule is limited to those three exact commands. The helper only accepts `on`, `off`, and `display-sleep`, and only calls:

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
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
launchctl bootout "gui/$(id -u)" /Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist
launchctl bootstrap "gui/$(id -u)" /Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist
```

For source installs, use `$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist` instead.

Capsomnia's LaunchAgent restarts the app after a crash or other unsuccessful exit. On startup, Capsomnia reads the current Caps Lock state and reapplies the matching sleep setting. Normal Quit still exits cleanly and does not restart the app.

Check the helper permissions:

```sh
sudo -n -l /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off \
  /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

If the helper permission check fails, run `./scripts/install.sh` again. Capsomnia checks the Caps Lock state every 250 milliseconds, so the menu bar dot may update by up to roughly a quarter second after the physical LED changes.

## Project Status

Capsomnia 1.0.0 is the first stable public release. See [CHANGELOG.md](CHANGELOG.md) for release history and [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

MIT
