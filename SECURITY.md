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

Capsomnia does not collect telemetry or require an account. Its network use includes an optional daily update check that reads GitHub's public release information (off switch in Advanced Settings), plus downloading installers from GitHub when you choose to update or install CLI & Skill. The optional "Keep hotspot connected" setting is off by default. When enabled while Capsomnia is on, it sends a single ICMP ping about once a minute to the local gateway only when the default route matches a recognized phone hotspot. Capsomnia sends no telemetry, identifiers, or personal data; the requests carry only standard network metadata.

Capsomnia observes Caps Lock changes independently of the "Prevent all-caps typing" setting. It registers local and global modifier-change monitors and filters them to Caps Lock events. When Input Monitoring access is already available, it also uses a non-exclusive HID monitor restricted to Caps Lock key presses and releases. The HID monitor does not prompt for permission; when observation is unavailable, the app falls back to its existing event handling and state polling. These monitors do not collect typed text.

When "Prevent all-caps typing" is enabled, it requires Accessibility permission for a local active Core Graphics event filter. The filter removes only the Caps Lock modifier and suppresses the Caps Lock modifier-change event; it does not log, persist, or transmit event contents. If the filter is unavailable, Capsomnia reports the input-assistance error and retries the filter while sleep prevention, the running timer, and normal on/off controls continue independently.

System sleep settings require elevated privileges, so Capsomnia installs a small root-owned native helper at:

```text
/Library/PrivilegedHelperTools/capsomnia-pmset
```

The sudoers rule only permits the current user to run:

```text
/Library/PrivilegedHelperTools/capsomnia-pmset on
/Library/PrivilegedHelperTools/capsomnia-pmset off
/Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
/Library/PrivilegedHelperTools/capsomnia-pmset indicator-hide
/Library/PrivilegedHelperTools/capsomnia-pmset indicator-show
/Library/PrivilegedHelperTools/capsomnia-pmset indicator-restore
```

The helper is a compiled executable. It does not invoke a shell or load shell startup files. It only accepts `on`, `off`, `display-sleep`, `indicator-hide`, `indicator-show`, and `indicator-restore`. The first three only execute `/usr/bin/pmset -a disablesleep` or `/usr/bin/pmset displaysleepnow`.

The indicator modes back the optional "Hide the Caps Lock indicator" setting. They only edit the fixed file `/Library/Preferences/FeatureFlags/Domain/UIKit.plist`. Before changing `redesigned_text_cursor.Enabled`, `indicator-hide` stores whether that value existed and its original value in `/Library/Application Support/Capsomnia/CapsLockIndicatorBackup.plist`, owned by root with mode `0600`. `indicator-show` restores that state after an explicit toggle-off. The uninstall-only `indicator-restore` restores it only when the backup exists, so a pre-existing user override is left untouched. Unrelated flags are preserved. Existing plist or backup data that cannot be read and validated is never replaced or deleted. The setting uses an undocumented system-wide macOS feature flag, may affect other text-cursor indicators, and takes effect after a restart.

When an auto-off timer expires, Capsomnia first turns Caps Lock off through the existing HID path and confirms that `SleepDisabled=0`. Only then does the app invoke `/usr/bin/pmset sleepnow` directly as the signed-in user. This immediate sleep request does not use `sudo`, does not add a helper mode, and does not expand the sudoers rule. If Caps Lock cannot be turned off or the sleep-prevention state cannot be confirmed, Capsomnia does not request sleep.

Package installs keep `/Applications/Capsomnia.app`, the helper, and the system LaunchAgent owned by `root:wheel`. The packaged helper and app are signed with the same Developer ID. The app process still runs as the signed-in user. Capsomnia verifies the actual `SleepDisabled` state after each change and every ten seconds afterward. If the helper cannot apply a sleep-state change, the actual state cannot be verified, or the setting drifts, Capsomnia shows a red status indicator and retries instead of reporting the requested state as active.

The LaunchAgent restarts Capsomnia after crashes. If the app is force-killed while crash recovery is disabled or unavailable, the last system sleep setting can remain active. Users can restore normal behavior with `sudo pmset -a disablesleep 0`.

## Optional local control (4.0.0 candidate)

cpsm communicates with a Unix socket owned by the signed-in user. The endpoint
directory is mode 0700, socket mode 0600, and both peers verify the effective UID.
There is no network listener. The CLI does not add privileged helper modes.
Explicit CLI off, including a toggle targeting off, verifies Caps Lock and
sleep-prevention release before requesting sleep as the signed-in user.

The optional Tools download uses an HTTPS release URL. Capsomnia checks the
installer's Developer ID team after downloading it and marks it as a downloaded
file. After administrator approval, it copies the package into a root-owned
private directory, checks the signature and Tools format of that copy, and
installs only that copy. The private directory is removed when installation
finishes or fails. Local preview builds may use an explicitly configured file
URL and unsigned packages; their protected copy is still checked for the Tools format. Tools
installers contain two CLIs and optional common Skills, written as the console
user. App uninstallation leaves these separately installed tools in place.
