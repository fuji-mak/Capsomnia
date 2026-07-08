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

sudo "$HELPER_PATH" off 2>/dev/null || /usr/bin/pmset -a disablesleep 0 2>/dev/null || true

rm -f "$LAUNCH_AGENT"
rm -rf "$APP_BUNDLE"
rm -rf "$LEGACY_INSTALL_DIR"
sudo rm -f "$SYSTEM_LAUNCH_AGENT"
sudo rm -rf "$SYSTEM_APP_BUNDLE"
sudo rm -f "$HELPER_PATH"
sudo rm -f "$LEGACY_HELPER_PATH"
sudo rm -f "$SUDOERS_PATH"

echo "Uninstalled $APP_NAME."
