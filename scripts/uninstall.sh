#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true

sudo "$HELPER_PATH" off 2>/dev/null || /usr/bin/pmset -a disablesleep 0 2>/dev/null || true

rm -f "$LAUNCH_AGENT"
rm -rf "$INSTALL_DIR"
sudo rm -f "$HELPER_PATH"
sudo rm -f "$SUDOERS_PATH"

echo "Uninstalled $APP_NAME."
