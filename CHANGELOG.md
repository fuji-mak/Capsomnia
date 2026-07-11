# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

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
