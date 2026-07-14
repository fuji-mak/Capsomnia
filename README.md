# Capsomnia OBS Edition

Capsomnia OBS Edition turns the MacBook Caps Lock key into a physical keep-awake switch designed for closed-lid recordings, screen capture, remote access, AI agents, builds, downloads, and other long-running local work.

This repository is an independently maintained derivative of [fuji-mak/Capsomnia](https://github.com/fuji-mak/Capsomnia). The original project established the Caps Lock interaction, privileged sleep-control helper, login agent, menu bar interface, and safety model. This edition preserves that foundation while changing closed-lid display behavior for workflows such as OBS.

Current fork version: `1.1.0`

## Why this edition exists

Upstream Capsomnia calls `pmset displaysleepnow` after the lid closes. That is appropriate when the goal is simply to keep background work running, but explicitly sleeping the display can interrupt screen capture or cause OBS sources and screen sharing to stop updating.

This edition treats the display session differently:

- Caps Lock on prevents system sleep.
- A `NoDisplaySleepAssertion` keeps the graphical display session active.
- A renewable `UserIsActive` assertion prevents idle screen locking while the session is active.
- Closing the lid does **not** request display sleep.
- The built-in panel brightness is set to 0% instead.
- Brightness is read immediately before dimming and restored to that exact value when the lid opens.
- macOS automatic brightness remains enabled and can continue adapting afterward.
- A 40 ms clamshell watcher runs only while the lid is closed for responsive restoration; normal Caps Lock polling remains at 250 ms.

This is intended to feel like an indefinite Amphetamine session controlled by the physical Caps Lock indicator, while avoiding unnecessary panel brightness behind the closed lid.

## Behavior

### Caps Lock on

- System sleep is disabled, whether the lid is open or closed.
- Display idle sleep and automatic idle locking are suppressed.
- Long-running processes continue.
- When the lid closes, the app captures the current built-in display brightness and sets brightness to 0% without calling `displaysleepnow`.
- When the lid opens, the captured brightness is restored immediately.

### Caps Lock off

- Normal macOS sleep behavior returns.
- Power assertions are released.
- Any brightness value held by Capsomnia is restored.

### Quitting or terminating

Capsomnia releases its assertions, restores brightness, and runs the privileged helper in `off` mode to restore normal sleep behavior.

## Requirements

- Apple silicon MacBook
- macOS 14 or later
- Xcode Command Line Tools or Xcode with Swift 6
- Administrator access during installation

The brightness feature dynamically uses macOS's private `DisplayServices` framework because Apple does not expose equivalent built-in-panel brightness control through a supported public API. This may require maintenance after major macOS updates.

## Install from source

There is currently no signed release package for this fork. Build and install the reviewed source locally:

```sh
git clone https://github.com/tarushvkodes/Capsomnia-OBS.git
cd Capsomnia-OBS
./scripts/install.sh
```

The installer:

1. Builds the Swift app and native helper locally.
2. Ad-hoc signs the assembled app so its resource seal verifies.
3. Installs `Capsomnia.app` in `~/Applications`.
4. Installs the native helper at `/Library/PrivilegedHelperTools/capsomnia-pmset`.
5. Adds a narrow sudoers rule permitting only the helper's `on` and `off` modes.
6. Creates a user LaunchAgent and starts Capsomnia at login.

The administrator password is used only for the helper and sudoers installation steps.

## Update

```sh
cd Capsomnia-OBS
git pull
./scripts/install.sh
```

The installer rebuilds the app and helper, replaces the installed files, refreshes the sudoers rule, and restarts the login agent.

## Uninstall

From the source checkout:

```sh
./scripts/uninstall.sh
```

Or from the installed app:

```sh
~/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

The uninstaller restores normal sleep, unloads the LaunchAgent, and removes the app, helper, logs, preferences, and sudoers rule.

## Verify installation

Check the process and sleep state:

```sh
pgrep -fl Capsomnia
pmset -g | grep SleepDisabled
```

With Caps Lock on, `SleepDisabled` should be `1`. With Caps Lock off, it should be `0`.

Inspect active assertions:

```sh
pmset -g assertions | grep -E 'Capsomnia|NoDisplaySleepAssertion|UserIsActive'
```

Check helper authorization:

```sh
sudo -n -l \
  /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off
```

Review logs:

```sh
tail -f ~/Library/Logs/Capsomnia/capsomnia.log
```

Useful log events include:

- `brightness_zero=ok`
- `brightness_restore=ok`
- `closed_lid_polling_started interval_ms=40`
- `closed_lid_polling_stopped`

## OBS verification workflow

Before relying on the app for an important recording:

1. Start a short OBS test recording.
2. Turn Caps Lock on and confirm the menu bar indicator is active.
3. Close the lid completely.
4. Leave it closed long enough to verify that the recording and captured source continue updating.
5. Open the lid and confirm that the previous brightness returns without a lock screen.
6. Review the recording and Capsomnia log.

macOS and MacBook hardware ultimately control whether an internal display remains logically available after the physical lid-detach event. This edition avoids deliberately sleeping the display and maintains the relevant power assertions, but it cannot guarantee every OBS capture source on every macOS release. Test the exact source type you plan to record.

## Power and thermal considerations

Closed-lid operation can increase heat and battery drain. Video recording and encoding are much more significant power consumers than the temporary 40 ms lid polling. Ensure adequate airflow, use external power for long sessions, and monitor temperatures during sustained workloads.

## Security model

The menu bar app does not run as root. The root-owned native helper accepts only:

```sh
/Library/PrivilegedHelperTools/capsomnia-pmset on
/Library/PrivilegedHelperTools/capsomnia-pmset off
```

Those modes map directly to:

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

The helper does not invoke a shell, load shell configuration, access the network, or accept arbitrary commands. Capsomnia makes no network requests, collects no telemetry, and requires no account.

## Development

Run the tests:

```sh
swift test -c release
```

Build an app bundle without installing:

```sh
./scripts/build-app.sh dist/Capsomnia.app
codesign --verify --deep --strict --verbose=2 dist/Capsomnia.app
```

## Upstream attribution and license

Original project: [fuji-mak/Capsomnia](https://github.com/fuji-mak/Capsomnia) by Taketo Fujimaki.

This derivative retains the original MIT license. See [LICENSE](LICENSE).
