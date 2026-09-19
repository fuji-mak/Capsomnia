#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
SYSTEM_APP_BUNDLE="/Applications/$APP_NAME.app"
LEGACY_INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SYSTEM_LAUNCH_AGENT="/Library/LaunchAgents/$LABEL.plist"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null || true
/usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true

sudo "$HELPER_PATH" off 2>/dev/null || sudo /usr/bin/pmset -a disablesleep 0 2>/dev/null || true
# Restore the exact setting captured when Capsomnia first hid the indicator.
# If no backup exists, the helper leaves any pre-existing override untouched.
if [[ -x "$HELPER_PATH" ]]; then
    set +e
    sudo "$HELPER_PATH" indicator-restore
    INDICATOR_RESTORE_STATUS=$?
    set -e
    # Exit 64 means an older helper that predates indicator backups. Any
    # actual restore error stops uninstall so the helper and backup survive.
    if (( INDICATOR_RESTORE_STATUS != 0 && INDICATOR_RESTORE_STATUS != 64 )); then
        echo "Could not restore the Caps Lock indicator setting; uninstall stopped." >&2
        exit "$INDICATOR_RESTORE_STATUS"
    fi
fi

rm -f "$LAUNCH_AGENT"
rm -rf "$APP_BUNDLE"
rm -rf "$LEGACY_INSTALL_DIR"
sudo rm -f "$SYSTEM_LAUNCH_AGENT"
sudo rm -rf "$SYSTEM_APP_BUNDLE"
sudo rm -f "$HELPER_PATH"
sudo rm -f "$LEGACY_HELPER_PATH"
sudo rm -f "$SUDOERS_PATH"

echo "Uninstalled $APP_NAME."
