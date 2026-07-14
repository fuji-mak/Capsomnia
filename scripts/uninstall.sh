#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
CURRENT_UID="$(/usr/bin/id -u)"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
SYSTEM_APP_BUNDLE="/Applications/$APP_NAME.app"
LEGACY_INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SYSTEM_LAUNCH_AGENT="/Library/LaunchAgents/$LABEL.plist"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"

/usr/bin/printf '正在退出 Capsomnia，并恢复正常休眠……\n'
/usr/bin/sudo -v

/bin/launchctl bootout "gui/$CURRENT_UID" "$LAUNCH_AGENT" 2>/dev/null || true
/bin/launchctl bootout "gui/$CURRENT_UID" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null || true
/usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true

# 必须先恢复正常休眠，再移除 helper 和授权规则。
if [[ -x "$HELPER_PATH" ]]; then
  /usr/bin/sudo "$HELPER_PATH" off \
    || /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
else
  /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
fi

/bin/rm -f "$LAUNCH_AGENT"
/bin/rm -rf "$APP_BUNDLE" "$LEGACY_INSTALL_DIR"
/usr/bin/sudo /bin/rm -f "$SYSTEM_LAUNCH_AGENT" "$HELPER_PATH" "$LEGACY_HELPER_PATH" "$SUDOERS_PATH"
/usr/bin/sudo /bin/rm -rf "$SYSTEM_APP_BUNDLE"

for path in "$APP_BUNDLE" "$SYSTEM_APP_BUNDLE" "$LAUNCH_AGENT" "$SYSTEM_LAUNCH_AGENT" "$HELPER_PATH" "$SUDOERS_PATH"; do
  if [[ -e "$path" ]]; then
    /usr/bin/printf '卸载未完成，仍有文件未移除：%s\n' "$path" >&2
    exit 1
  fi
done

/usr/bin/printf 'Capsomnia 已完全卸载，Mac 已恢复正常休眠。\n'
