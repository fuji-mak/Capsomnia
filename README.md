# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia icon" width="128" height="128">
</p>

[日本語 README](README.ja.md)

Current version: `0.2.0`

Capsomnia is a tiny macOS menu bar app that uses Caps Lock as a physical keep-awake switch.

When Caps Lock is on, Capsomnia disables system sleep with `pmset`. When Caps Lock is off, it restores normal sleep behavior.

## What It Does

- Caps Lock on: runs `pmset -a disablesleep 1`
- Caps Lock off: runs `pmset -a disablesleep 0`
- Green menu bar dot: sleep is disabled
- Gray menu bar dot: normal sleep behavior
- Quitting the app restores normal sleep behavior

Capsomnia is useful when long-running local jobs, AI coding agents, builds, downloads, or scripts should keep running while you step away.

## Why Not `caffeinate`?

`caffeinate` is great for preventing idle sleep while your Mac is open. Closing a MacBook lid is different: normal `caffeinate` assertions do not reliably keep local jobs running in closed-lid use.

Capsomnia uses `pmset -a disablesleep 1`, which disables system sleep itself. This is more suitable when you explicitly want long-running local work to continue while the lid is closed.

## Safety Notes

- Closed-lid background work is the intended use case: SSH, mobile agent control, builds, downloads, and other long-running jobs.
- Sleep-disabled closed-lid use can increase heat and battery drain.
- Use good judgment for airflow, power, and runtime when leaving your Mac unattended.
- Capsomnia is a manual switch: Caps Lock on means "keep running", Caps Lock off means "normal sleep behavior".

## Requirements

- macOS 14 or later
- Swift 6 toolchain
- Administrator access during installation

Capsomnia is currently distributed as source. The install script builds `Capsomnia.app` locally.

## Install

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

The installer:

1. Builds the Swift executable in release mode.
2. Builds and installs `Capsomnia.app` into `~/Applications/`.
3. Installs a fixed root-owned helper at `/Library/PrivilegedHelperTools/capsomnia-pmset`.
4. Adds a narrow sudoers rule for the current user.
5. Installs and starts a LaunchAgent.

The app starts automatically at login after installation.

## Uninstall

```sh
./scripts/uninstall.sh
```

The uninstaller unloads the LaunchAgent, removes `~/Applications/Capsomnia.app`, removes the helper, removes the sudoers rule, and restores normal sleep behavior.

## Security Model

Capsomnia's menu bar app does not run as root. System sleep settings require elevated privileges, so Capsomnia uses a small fixed helper through passwordless `sudo`.

The app can only invoke:

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
```

The sudoers rule is limited to those two exact commands. The helper only accepts `on` and `off`, and only calls:

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

## Logs

Logs are written to:

```text
~/Library/Logs/Capsomnia/
```

## Website Development

The GitHub Pages site lives in `docs/`. The HTML is written with Tailwind CSS utility classes.

```sh
npm install
npm run build:site
```

Main files:

- `docs/index.html`: page structure and Tailwind classes
- `docs/styles.input.css`: site variables, small custom CSS, and Tailwind input
- `docs/styles.css`: generated CSS
- `docs/capsomnia.js`: language switcher and copy behavior

## Troubleshooting

Check whether sleep is disabled:

```sh
pmset -g | grep disablesleep
```

Restart the LaunchAgent:

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
```

If the menu bar dot does not react immediately, Capsomnia also polls the Caps Lock state once per second as a fallback.

## License

MIT

## Project Status

Capsomnia is in early public release. See [CHANGELOG.md](CHANGELOG.md) for release history and [SECURITY.md](SECURITY.md) for vulnerability reporting.
