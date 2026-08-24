# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

- Add a built-in, dependency-free update check. "Check for Updates…" in the menu bar menu queries the GitHub releases API, and an opt-out daily automatic check (Advanced Settings) surfaces new versions as "Update available" in the menu. Choosing to update downloads the signed installer package to the Downloads folder and opens it; after the update is installed, Capsomnia offers once to move the downloaded installer to the Trash. Only the latest version number is requested — no telemetry.

## 3.4.0 - 2026-08-24

- Refocus the menu bar menu on day-to-day controls: choose an auto-off timer preset, see the live remaining time while it runs, open the custom timer editor, and toggle "Keep display awake" without opening Settings.
- Keep the less frequently changed menu bar visibility and language controls in Settings, while preserving the compact 24-point LED status item.

## 3.3.0 - 2026-08-23

- Simplify display behavior to a single opt-in "Keep display awake" setting. By default, closing the lid puts the display to sleep while work continues. When enabled, Capsomnia prevents idle display sleep and skips its forced lid-close display sleep so the display session remains available for remote UI operation such as Computer Use.
- Reorganize Settings around frequency of use. The regular window now puts "Keep display awake" and the auto-off timer up front, while initial setup keeps its onboarding choices and Advanced Settings holds the less frequently changed environment, login, lid-closed Caps Lock guard, and shortcut options.
- Preserve the Developer ID signatures of the app and privileged helper through package installation by signing both executables in their final package payload locations and verifying the nested signatures after packaging.

## 3.2.0 - 2026-08-23

- Add an opt-in "Keep display awake" setting (default off) to Advanced Settings. While Capsomnia is on, the display no longer turns off after the idle time configured in macOS. The assertion is held in-process without new privileges, is released when Capsomnia turns off or the app quits, and is independent of "Turn display off when lid closes", which still turns the display off after the lid closes. (#88)

## 3.1.2 - 2026-08-22

- Preserve an explicitly disabled "Open at login" preference during package and source upgrades, while retaining the enabled-by-default behavior for new installations. (#86)

## 3.1.1 - 2026-08-16

- Prevent reselecting the current auto-off preset or opening and closing the unchanged Custom editor from restarting an active countdown. Use the existing Restart action for intentional resets. (#84)

## 3.1.0 - 2026-08-13

- Add Intel Mac source-install support for macOS 13.5 or later with Swift 5.9, while keeping the signed and notarized package Apple silicon-only on macOS 14 or later.
- Add an opt-in "Ignore Caps Lock turn-offs while the lid is closed" setting (default off) to Advanced Settings. While the lid is closed, Caps Lock turn-offs from external sources — such as a remote desktop client syncing its keyboard state to the host — are ignored and Caps Lock is re-asserted, so sleep prevention survives remote sessions. Turn-offs from the menu bar, the registered shortcut, and the auto-off timer stay effective, and opening the lid with Caps Lock off returns to normal sleep behavior. (#75)

## 3.0.0 - 2026-08-10

- Add an optional auto-off timer with 15-minute through 8-hour presets, a one-minute to 24-hour custom picker, a live countdown, and an explicit restart action in Advanced Settings.
- When the timer expires, turn Caps Lock off, confirm that `SleepDisabled` has returned to normal, and then request immediate system sleep exactly once. Do not sleep if Caps Lock cannot be turned off or the sleep-prevention state cannot be confirmed.
- Keep the menu bar compact by leaving the countdown in Settings, and start a fresh full-duration timer whenever Capsomnia is enabled again.
- Move custom time controls into a fixed popover, support one-minute adjustments, and coalesce rapid setting changes for immediate UI feedback without shifting the two-column layout.

## 2.0.4 - 2026-08-05

- Prevent command execution deadlocks by draining standard output and standard error concurrently.
- Prevent main run-loop re-entry from launching nested `pmset` processes during sleep-state polling.

## 2.0.3 - 2026-07-27

- Preserve sleep prevention when macOS clears Caps Lock while switching from an IME to a keyboard layout such as ABC or U.S.
- Re-assert Caps Lock after selected input source changes while honoring intentional physical-key, menu, and registered-shortcut toggles.
- Coalesce input-source notifications and tolerate transient HID readback delays during Caps Lock recovery.

## 2.0.2 - 2026-07-24

- Replace the nonfunctional clickable Clear control with concise Del and Esc keyboard hints while editing an assigned shortcut.
- Keep both the Mac Delete key and Forward Delete available for clearing the shortcut, while Esc cancels without changing it.

## 2.0.1 - 2026-07-24

- Cancel shortcut recording when Settings closes so reopening Capsomnia cannot preserve a stale “Press keys…” state or leave the saved global shortcut suspended.
- Add an explicit localized Clear button while editing an assigned shortcut, with language-independent padding that matches the adjacent Esc action.
- Keep Delete and Forward Delete as keyboard alternatives for clearing an assigned shortcut.

## 2.0.0 - 2026-07-21

- Add reliable Caps Lock toggling from the menu bar by using the real IOHID modifier-lock state as the single source of truth for the physical LED, menu bar status, and sleep prevention.
- Add a persistent global toggle shortcut with conflict handling, support for Command, Option, or Control combinations, and Shift with F1–F20.
- Redesign Settings with a focused main page and a larger Advanced Settings page that keeps every preference in one window.
- Clarify Capsomnia-on behavior across all four app languages and add a high-resolution shortcut-settings preview to every localized landing page.
- Remove redundant security explanation cards from the landing page while retaining the helper restrictions and heat and battery guidance.

## 1.1.0 - 2026-07-19

- Add the optional "Prevent all-caps typing" setting. When enabled, the Caps Lock indicator continues to control Capsomnia while normal typing is no longer locked to uppercase. Shift and other modifiers continue to work normally.
- Add the setting and its Accessibility explanation in English, Japanese, Simplified Chinese, and Korean.
- Simplify initial setup to the menu bar icon, the optional typing setting, and language while keeping display sleep on lid close and launch at login enabled by default and editable later.
- Keep menu bar visibility independent from the typing setting while continuing to show a temporary red indicator for errors.
- Clarify the optional Accessibility behavior on all four localized landing pages.
- Polish Korean display-sleep and README wording.

## 1.0.3 - 2026-07-18

- Add Simplified Chinese and Korean localizations to the macOS app, README, and website.
- Replace the app's segmented language control with a compact pop-up menu for English, Japanese, Simplified Chinese, and Korean.
- Move the official website to `capsomnia.com`, add localized routes, and route first visits by browser language through Cloudflare Workers while preserving redirects from the previous GitHub Pages URL.
- Refine the README and landing-page download buttons, language navigation, localized metadata, and support links.

## 1.0.2 - 2026-07-16

- Keep external displays active in clamshell mode by skipping forced display sleep whenever an online external display is connected. If the display state cannot be determined, Capsomnia now fails safely without requesting display sleep.
- Add a GitHub Sponsors funding link for users who want to support ongoing development.

## 1.0.1 - 2026-07-15

- Associate the installed LaunchAgent with the Capsomnia app bundle so new background-item registrations can show the app name and icon instead of falling back to the Developer ID name. Existing macOS registrations may retain their cached label.
- Add concise usage and safety guidance covering heat, battery drain, normal sleep restoration, critical jobs, backups, and the software warranty boundary.
- Keep the canonical landing page Japanese for search indexing and move the no-network, no-telemetry, no-account privacy promise closer to the product introduction.
- Remove unused app and site code and consolidate duplicated internal implementations without intentionally changing behavior.

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
