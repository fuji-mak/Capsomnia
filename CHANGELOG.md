# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

## 1.5.0 - 2026-07-15

- Sleep only after the MacBook lid is confirmed closed; an open or unknown lid state never triggers AI-completion sleep.
- Track Codex and Claude lifecycle events across concurrent sessions and subagents; any confirmed running work blocks sleep without an age-based timeout.
- Keep permission requests and incomplete lifecycle states awake until correlated completion evidence arrives; never sleep from a waiting timeout alone.
- Persist identifier-only activity state with locking, atomic replacement, deduplication, and fail-safe recovery after malformed or incomplete events.
- Add closed-lid battery protection: on battery power at 10% or below, restore normal sleep and sleep the Mac even if AI work remains active.
- Add exact Codex lifecycle-hook installation and removal while preserving unrelated hooks and the user's previous notifier.
- Keep lifecycle hooks subject to Codex's normal `/hooks` review and trust flow.

## 1.4.0 - 2026-07-15

- Add the persistent, default-on “Sleep After Codex/Claude Tasks Finish” menu item.
- Preserve Codex's existing completion notifier through a local forwarding bridge.
- Add Claude Code Stop-hook integration when Claude is installed.
- Recheck integrations at app launch and whenever the status menu opens, so tools installed later are detected without reinstalling Capsomnia.
- Wait 30 seconds after a task finishes and expose a one-time Cancel command before sleeping.
- Restore normal sleep, invoke the restricted `pmset sleepnow` helper action, then restore keep-awake mode after the Mac wakes.
- Remove only Capsomnia-owned Codex and Claude integration entries during uninstall.

- Rename all three controls to describe their behavior in plain language.
- Align the primary switch label with the native menu content inset.
- Expand the primary row for longer English and Japanese labels instead of truncating them.
- Show a menu warning while sleep-setting recovery is in progress.
- Enforce a single running instance with both process detection and a file lock.
- Let launchd retry a temporary duplicate and wait for old processes during upgrades.
- Read the real launchd state instead of trusting the saved login-start preference.
- Reduce background polling and react immediately when displays wake.
- Verify keep-awake state every 60 seconds only while enabled.
- Check for lid closure every five seconds while open, then stop polling after closure.

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
