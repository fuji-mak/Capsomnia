# Changelog

All notable changes to Capsomnia will be documented in this file.

## Unreleased

## 0.3.8 - 2026-07-11

- Split the first-run onboarding window into two columns so the initial screen is shorter.
- Reopen Capsomnia after the macOS Input Monitoring "Quit & Reopen" flow when macOS does not bring it back automatically.

## 0.3.7 - 2026-07-11

- Added onboarding and documentation for Input Monitoring and the macOS background item prompt.

## 0.3.6 - 2026-07-08

- Restart Capsomnia after crashes through a crash-only LaunchAgent `KeepAlive` rule, then reapply the current Caps Lock sleep state on startup.
- Bundle the uninstaller inside `Capsomnia.app` so package users can uninstall without cloning the repository.
- Documented that Capsomnia itself makes no network requests, collects no telemetry, and requires no account.
- Documented the manual `sudo pmset -a disablesleep 0` recovery command.
- Fixed uninstaller fallback recovery so it can restore normal sleep behavior even if the helper path is unavailable.
- Removed `dist/` prefixes from generated `SHA256SUMS.txt` entries.
- Prevented AppleDouble `._*` files from being included in package payloads.

## 0.3.5 - 2026-07-08

Public release process hardening.

- Switched public download links to the stable `Capsomnia.pkg` release asset.
- Restored the signed package build and notarization scripts to the public repository.
- Documented Input Monitoring behavior and the one-second polling fallback.
- Updated the security reporting contact to a working X profile.
- Added CI coverage for committed generated site CSS.
- Synchronized landing page static copy with the localization dictionary.
- Removed an unused settings title string.

## 0.3.4 - 2026-07-08

Single-instance installer release.

- Prevented package installs from starting a second Capsomnia process.
- Stopped existing Capsomnia processes before relaunching from the LaunchAgent during install.
- Added an app-side duplicate-instance guard so accidental second launches exit without changing sleep state.

## 0.3.3 - 2026-07-08

Installer welcome release.

- Open Capsomnia after source or package installation so the welcome screen appears.
- Keep the package-installed app fixed at `/Applications/Capsomnia.app`.

## 0.3.2 - 2026-07-08

Repository cleanup release.

- Removed release packaging scripts from the public source archive.
- Removed stale project metadata and unused site CSS variables.

## 0.3.1 - 2026-07-08

Signed package distribution.

- Published Developer ID signed and Apple notarized package distribution.
- Kept release packaging steps outside the public repository.
- Updated uninstall cleanup for both package and source installs.
- Updated English and Japanese documentation for signed package installation.

## 0.3.0 - 2026-06-30

Closed-lid display sleep setting.

- Added optional display sleep when the MacBook lid closes while Caps Lock is on.
- Added a settings toggle for closed-lid display sleep, enabled by default.
- Expanded the privileged helper and sudoers rule to allow only the new `display-sleep` helper command in addition to `on` and `off`.
- Updated English and Japanese documentation.

## 0.2.0 - 2026-06-29

App bundle release.

- Added `Capsomnia.app` bundle generation.
- Added `Info.plist` and `AppIcon.icns`.
- Updated installation to place the app at `~/Applications/Capsomnia.app`.
- Updated LaunchAgent startup to run the app bundle executable.
- Kept the existing privileged helper and sudoers security model.

## 0.1.3 - 2026-06-29

Documentation and asset update.

- Added the initial Capsomnia LED icon asset.
- Displayed the icon in the English and Japanese README files.

## 0.1.2 - 2026-06-28

Documentation cleanup.

- Reworded safety notes to match Capsomnia's intended closed-lid background-work use case.

## 0.1.1 - 2026-06-28

Documentation cleanup.

- Removed obsolete installer troubleshooting text from the README files.

## 0.1.0 - 2026-06-28

Initial public release.

- Added Caps Lock driven sleep disable/restore behavior.
- Added macOS menu bar status indicator.
- Added LaunchAgent based startup.
- Added root-owned privileged helper for `pmset`.
- Added narrow sudoers rule limited to helper `on` and `off`.
- Added English and Japanese README files.
- Added install and uninstall scripts.
