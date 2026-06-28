# Capsomnia

Capsomnia is a small macOS menu bar app that toggles system sleep prevention with Caps Lock.

- Caps Lock on: `pmset -a disablesleep 1`
- Caps Lock off: `pmset -a disablesleep 0`
- Green menu bar dot: sleep is disabled
- Gray menu bar dot: normal sleep behavior

This is intended for workflows where closing the lid or system sleep would interrupt long-running local jobs.

## Requirements

- macOS 14 or later
- Swift 6 toolchain
- Administrator access during installation

## Install

```sh
./scripts/install.sh
```

The installer:

1. Builds the Swift executable in release mode.
2. Installs the app binary into `~/Library/Application Support/Capsomnia/`.
3. Installs a fixed root-owned helper at `/usr/local/sbin/capsomnia-pmset`.
4. Adds a narrow sudoers rule that only allows the current user to run that helper with `on` or `off`.
5. Installs and starts a LaunchAgent.

## Uninstall

```sh
./scripts/uninstall.sh
```

The uninstaller unloads the LaunchAgent, removes the app binary, removes the helper, removes the sudoers rule, and restores normal sleep behavior.

## Security model

The menu bar app does not run as root. It invokes:

```sh
sudo -n /usr/local/sbin/capsomnia-pmset on
sudo -n /usr/local/sbin/capsomnia-pmset off
```

The sudoers rule is limited to those two exact commands. The helper itself only accepts `on` and `off`, and only calls `/usr/bin/pmset -a disablesleep`.

## Logs

Logs are written to:

```text
~/Library/Logs/Capsomnia/
```

## License

MIT
