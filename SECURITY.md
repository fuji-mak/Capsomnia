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

Capsomnia does not collect telemetry or require an account. Its network use includes an optional daily update check that reads GitHub's public release information (off switch in Advanced Settings), downloading installers from GitHub when you choose to update or install CLI & Skill, optional local gateway probes for Keep hotspot connected, and optional SSID-filtered Wi-Fi scanning and association for Auto-connect to hotspot. Capsomnia sends no telemetry. Release requests carry standard network metadata. Local Wi-Fi discovery and authentication use the configured SSID and credential with macOS and the target hotspot.

Auto-connect is off by default and requires a nonempty configured SSID and a raw effective Caps Lock session. It starts reconnect work only after a Wi-Fi path outage lasts at least five seconds. It does not contact an external server or send a password to a subprocess. Passwords persist only as generic-password items in the signed-in user's login Keychain, under the Capsomnia hotspot service and SSID account. SSID and opt-in persist in UserDefaults. Passwords do not appear in preferences, logs, status, process arguments, or the CLI.

Automatic reads and explicit Settings edits share a serial queue. Reads disable the legacy login Keychain prompt switch, restore its prior state, and fail visibly if the switch, read, or restoration fails. A per-query LAContext also disallows interaction, but Capsomnia does not rely on that context alone for the file-based login Keychain. Save and Forget are explicit user actions that may show a Keychain permission dialog. An unreadable or foreign-access item is never automatically deleted or replaced to bypass access controls. The secure password field clears after Save or window closure.

Location Services access is requested only through the hotspot Settings action and supports CoreWLAN network visibility. Capsomnia does not request location coordinates or store location history. Recovery, stop, configuration changes, and credential edits revoke pending join work. Generation and healthy-path checks run before credential work, after the read, after the scan, and immediately before association. A CoreWLAN association call that has already begun is not cancellable; cancellation suppresses its result and further retries but cannot undo that call.

The Wi-Fi Settings link describes macOS 26 or later's native Instant Hotspot Automatic setting. macOS can wake a nearby iPhone with the same Apple Account or Family Sharing and Wi-Fi and Bluetooth enabled. That system preference also works while Capsomnia is off. Capsomnia does not use private phone activation APIs or runtime UI automation. Password-based CoreWLAN reconnect requires an already broadcasting hotspot. Full end-to-end phone wake and connection has not been tested in this implementation.

When "Prevent all-caps typing" is disabled, Capsomnia does not request Input Monitoring or inspect keyboard events. When enabled, it requires Accessibility permission for a local active Core Graphics event filter. The filter removes only the Caps Lock modifier and suppresses the Caps Lock modifier-change event; it does not log, persist, or transmit event contents. If the filter is unavailable, Capsomnia turns sleep prevention off and reports an error instead of acting on the physical switch.

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
installer's Developer ID team before opening it and marks it as a downloaded
file. Local preview builds may use an explicitly configured file URL. Tools
installers contain two CLIs and optional common Skills, written as the console
user. App uninstallation leaves these separately installed tools in place.
