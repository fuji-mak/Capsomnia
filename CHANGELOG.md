# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

- Restyle the settings window after the macOS 26 Figma kit in dark mode: System Settings–style grouped lists with inset separators, frosted dark material, and a system-green switch. Keep the original full-width LED Done / Get started button. Capsomnia LED green stays on the CTA, status dots, and app icon.
- Force the app appearance to dark mode so light system appearance does not wash out the UI.
- Regenerate `resources/AppIcon.icns` from `resources/CapsomniaIcon.svg`.

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
