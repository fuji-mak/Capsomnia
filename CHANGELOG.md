# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

## 1.1.0 - 2026-07-14

- Keep the graphical session active with display-sleep and user-activity power assertions while Caps Lock is on.
- Replace the closed-lid `displaysleepnow` request with built-in panel brightness control for OBS and screen-capture continuity.
- Capture brightness immediately before dimming to 0% and restore that exact value when the lid opens.
- Use adaptive 40 ms clamshell polling only while the lid is closed; retain 250 ms polling during normal operation.
- Preserve macOS automatic-brightness behavior after restoration.
- Remove the obsolete privileged `display-sleep` helper command and narrow the sudoers rule to `on` and `off`.
- Ad-hoc sign locally assembled source builds so their resource seals verify on current macOS versions.

## 1.0.0 - 2026-07-12

First stable release of Capsomnia.

- Toggle system sleep prevention with Caps Lock while keeping normal sleep behavior one switch away.
- Keep local work running with the MacBook lid closed, with optional display sleep.
- Provide a signed and notarized installer, a restricted root-owned helper, crash recovery, and a bundled uninstaller.
- Detect Caps Lock through local 250-millisecond polling without requesting Input Monitoring permission.
- Replace the shell-based privileged helper with a signed native executable that never loads shell startup files.
- Verify the actual `SleepDisabled` state after changes and every ten seconds, then recover from drift.
- Keep the previous applied state when the privileged helper fails, show a red error indicator, and retry after five seconds.
- Preserve root ownership for every system package payload entry and verify package ownership in CI.
- Make no network requests, collect no telemetry, and require no account.
