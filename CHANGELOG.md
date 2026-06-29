# Changelog

All notable changes to Capsomnia will be documented in this file.

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
