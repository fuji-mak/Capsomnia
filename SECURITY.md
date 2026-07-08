# Security Policy

## Supported Versions

Capsomnia is currently in early public release. Security fixes target the latest `main` branch and tagged releases.

| Version | Supported |
| --- | --- |
| 0.3.x | Yes |
| 0.2.x | No |
| 0.1.x | No |

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

System sleep settings require elevated privileges, so Capsomnia installs a small root-owned helper at:

```text
/Library/PrivilegedHelperTools/capsomnia-pmset
```

The sudoers rule only permits the current user to run:

```text
/Library/PrivilegedHelperTools/capsomnia-pmset on
/Library/PrivilegedHelperTools/capsomnia-pmset off
/Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

The helper only accepts `on`, `off`, and `display-sleep`. It only calls `/usr/bin/pmset -a disablesleep` or `/usr/bin/pmset displaysleepnow`.
