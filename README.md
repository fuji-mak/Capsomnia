# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia icon" width="128" height="128">
</p>

<p align="center">
  <a href="README.ja.md"><img alt="日本語 README" src="https://img.shields.io/badge/README-JA-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://fuji-mak.github.io/Capsomnia/"><img alt="Website" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

Current version: `0.3.5`

[日本語 README](README.ja.md) · [Download `Capsomnia.pkg`](https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia.pkg)

Capsomnia is a small macOS menu bar app that turns Caps Lock into a physical keep-awake switch for closed-lid MacBook work.

Turn Caps Lock on when local work should keep running. Turn Caps Lock off when you want normal sleep behavior back.

It is useful for AI agents, mobile access, and other long-running or remote work.

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="Caps Lock light on" width="560">
</p>

<p align="center">
  <em>When this tiny light is on, your Mac stays awake.</em>
</p>

## Quick Start

Requirements:

- macOS 14 or later
- Administrator access during installation

Install the signed package:

1. Download `Capsomnia.pkg` from [GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest).
2. Open the package and follow the installer.

Release packages are signed with Developer ID and notarized by Apple. The package installs `Capsomnia.app` in `/Applications`, installs the privileged sleep-control helper, adds a narrow sudoers rule, and starts the LaunchAgent. Capsomnia opens after installation and starts automatically at login afterward.

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

- Caps Lock on: keeps AI agents and other work from being interrupted when the MacBook lid is closed. Remote operation through tools such as Codex Mobile remains possible. The Caps Lock light physically shows the current state.
- Caps Lock off: restores normal sleep behavior.
- Lid closed while Caps Lock is on: puts only the display to sleep while work keeps running.
- Quitting the app restores normal sleep behavior.

Capsomnia is useful for long-running local jobs, AI coding agents, SSH sessions, builds, downloads, and unattended scripts.

## Settings

On first launch, Capsomnia opens a small initial settings window where you can choose:

- whether to show the menu bar dot
- English or Japanese

Open Capsomnia again later to change:

- menu bar dot visibility
- display sleep when the lid closes, enabled by default
- language
- opening at login, enabled by default

You can open Capsomnia from `/Applications/Capsomnia.app` after package installation, from `~/Applications/Capsomnia.app` after source installation, or from the menu bar item while it is visible.

## Why Not `caffeinate`?

`caffeinate` is useful for preventing idle sleep while your Mac is open. Closing a MacBook lid is different: normal `caffeinate` assertions do not reliably keep local jobs running in closed-lid use.

Capsomnia keeps work running in closed-lid use the same way it would while the lid is open. The yellow-green Caps Lock light makes that state visible.

## Safety Notes

- Sleep-disabled closed-lid use can increase heat and battery drain.
- Use good judgment for airflow, power, and runtime when leaving your Mac unattended.
- Capsomnia is a manual switch: Caps Lock on means "keep running"; Caps Lock off means "normal sleep behavior".

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

Capsomnia's menu bar app does not run as root. System sleep settings require elevated privileges, so Capsomnia uses a small fixed helper through passwordless `sudo`.

Capsomnia itself does not make network requests, collect telemetry, or require an account.

Capsomnia tries to use a local macOS event tap so Caps Lock changes are detected immediately. macOS may classify this as Input Monitoring. Capsomnia does not record or upload keystrokes; it only checks the Caps Lock flag. If the permission is not granted, Capsomnia falls back to polling the Caps Lock state once per second.

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
pmset -g | grep disablesleep
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

If the helper permission check fails, run `./scripts/install.sh` again. If the menu bar dot does not react immediately, Capsomnia also polls the Caps Lock state once per second as a fallback.

## Project Status

Capsomnia is in early public release. See [CHANGELOG.md](CHANGELOG.md) for release history and [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

MIT
