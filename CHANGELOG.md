# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

## 1.3.1 - 2026-07-14

- Rebuild the app around one native menu-bar menu; no separate settings window.
- Make **Enabled** the direct keep-running switch and keep secondary options as checkmark items.
- Add natural Simplified Chinese alongside Japanese and English.
- Reapply display sleep while the lid stays closed, including external-display use.
- Tighten install, uninstall, helper, logging, and CI checks.

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
