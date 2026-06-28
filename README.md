# Capsomnia

[日本語 README](README.ja.md)

Capsomnia is a tiny macOS menu bar app that uses Caps Lock as a physical keep-awake switch.

When Caps Lock is on, Capsomnia disables system sleep with `pmset`. When Caps Lock is off, it restores normal sleep behavior.

## What It Does

- Caps Lock on: runs `pmset -a disablesleep 1`
- Caps Lock off: runs `pmset -a disablesleep 0`
- Green menu bar dot: sleep is disabled
- Gray menu bar dot: normal sleep behavior
- Quitting the app restores normal sleep behavior

Capsomnia is useful when long-running local jobs, AI coding agents, builds, downloads, or scripts should keep running while you step away.

## Requirements

- macOS 14 or later
- Swift 6 toolchain
- Administrator access during installation

Capsomnia is currently distributed as source. The install script builds the app locally.

## Install

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

The installer:

1. Builds the Swift executable in release mode.
2. Installs the app binary into `~/Library/Application Support/Capsomnia/`.
3. Installs a fixed root-owned helper at `/Library/PrivilegedHelperTools/capsomnia-pmset`.
4. Adds a narrow sudoers rule for the current user.
5. Installs and starts a LaunchAgent.

The app starts automatically at login after installation.

## Uninstall

```sh
./scripts/uninstall.sh
```

The uninstaller unloads the LaunchAgent, removes the app binary, removes the helper, removes the sudoers rule, and restores normal sleep behavior.

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

## Troubleshooting

If installation fails with an error like this:

```text
install: /usr/local/sbin/INS...: No such file or directory
```

Update to the latest `main` branch and run `./scripts/install.sh` again. Older installer versions installed the helper under `/usr/local/sbin`, which may not exist on some Macs.

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
