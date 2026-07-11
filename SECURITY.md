# Security Policy

## Security Updates

Security fixes are provided only for the latest release. Older releases are not maintained.

## Reporting a Vulnerability

Please do not open a public issue for sensitive security reports.

Report sensitive vulnerabilities by contacting the project maintainer on X:

- X: https://x.com/tf_makimaki
- Repository: https://github.com/fuji-mak/Capsomnia
- Maintainer: https://github.com/fuji-mak

For non-sensitive bugs or documentation issues, opening a public GitHub issue is fine.

Please include:

- A short summary of the issue.
- Steps to reproduce.
- The macOS version.
- Whether the issue affects install, uninstall, sudoers, the privileged helper, or runtime behavior.

## Security Model

Capsomnia's menu bar app runs as the current user. It does not run as root.

Capsomnia itself does not make network requests, collect telemetry, or require an account.

Capsomnia does not request Input Monitoring or read keyboard events. It checks only the local Caps Lock state every 250 milliseconds.

System sleep settings require elevated privileges, so Capsomnia installs a small root-owned native helper at:

```text
/Library/PrivilegedHelperTools/capsomnia-pmset
```

The sudoers rule only permits the current user to run:

```text
/Library/PrivilegedHelperTools/capsomnia-pmset on
/Library/PrivilegedHelperTools/capsomnia-pmset off
/Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

The helper is a compiled executable. It does not invoke a shell or load shell startup files. It only accepts `on`, `off`, and `display-sleep`, and only executes `/usr/bin/pmset -a disablesleep` or `/usr/bin/pmset displaysleepnow`.

Package installs keep `/Applications/Capsomnia.app`, the helper, and the system LaunchAgent owned by `root:wheel`. The packaged helper and app are signed with the same Developer ID. The app process still runs as the signed-in user. Capsomnia verifies the actual `SleepDisabled` state after each change and every ten seconds afterward. If the helper cannot apply a sleep-state change, the actual state cannot be verified, or the setting drifts, Capsomnia shows a red status indicator and retries instead of reporting the requested state as active.

The LaunchAgent restarts Capsomnia after crashes. If the app is force-killed while crash recovery is disabled or unavailable, the last system sleep setting can remain active. Users can restore normal behavior with `sudo pmset -a disablesleep 0`.
