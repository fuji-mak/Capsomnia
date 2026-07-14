#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
ROOT_DIR="$(cd "$(/usr/bin/dirname "$0")/.." && /bin/pwd)"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
LEGACY_APP_BUNDLE="$HOME/Library/Application Support/$APP_NAME/$APP_NAME.app"
LOG_DIR="$HOME/Library/Logs/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"
CURRENT_USER="$(/usr/bin/id -un)"
CURRENT_UID="$(/usr/bin/id -u)"

if [[ -z "$CURRENT_USER" || "$CURRENT_USER" == "root" || "$CURRENT_USER" == *[!A-Za-z0-9._-]* ]]; then
  /usr/bin/printf '无法为当前账户创建安全的授权规则：%s\n' "$CURRENT_USER" >&2
  exit 64
fi

build_tmp="$(/usr/bin/mktemp -d)"
rollback_root=""
sudoers_tmp=""
install_started=false
install_completed=false
had_app=false
had_launch_agent=false
had_helper=false
had_legacy_helper=false
had_sudoers=false

cleanup() {
  local status=$?
  local rollback_failed=false
  trap - EXIT

  if [[ "$status" -ne 0 && "$install_started" == "true" && "$install_completed" != "true" ]]; then
    /usr/bin/printf '安装未完成，正在恢复安装前的版本与授权设置……\n' >&2
    /bin/launchctl bootout "gui/$CURRENT_UID" "$LAUNCH_AGENT" 2>/dev/null || true
    /usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true
    if [[ -x "$HELPER_PATH" ]]; then
      /usr/bin/sudo -n "$HELPER_PATH" off 2>/dev/null \
        || /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null \
        || rollback_failed=true
    fi
    if [[ "$had_sudoers" == "true" ]]; then
      /usr/bin/sudo -n /bin/cp -p "$rollback_root/sudoers" "$SUDOERS_PATH" 2>/dev/null \
        || rollback_failed=true
      /usr/bin/sudo -n /usr/bin/cmp -s "$rollback_root/sudoers" "$SUDOERS_PATH" 2>/dev/null \
        || rollback_failed=true
    else
      /usr/bin/sudo -n /bin/rm -f "$SUDOERS_PATH" 2>/dev/null || rollback_failed=true
      /usr/bin/sudo -n /bin/test ! -e "$SUDOERS_PATH" 2>/dev/null || rollback_failed=true
    fi
    if [[ "$had_helper" == "true" ]]; then
      /usr/bin/sudo -n /bin/cp -p "$rollback_root/helper" "$HELPER_PATH" 2>/dev/null \
        || rollback_failed=true
      /usr/bin/sudo -n /usr/bin/cmp -s "$rollback_root/helper" "$HELPER_PATH" 2>/dev/null \
        || rollback_failed=true
    else
      /usr/bin/sudo -n /bin/rm -f "$HELPER_PATH" 2>/dev/null || rollback_failed=true
      /usr/bin/sudo -n /bin/test ! -e "$HELPER_PATH" 2>/dev/null || rollback_failed=true
    fi
    if [[ "$had_legacy_helper" == "true" ]]; then
      /usr/bin/sudo -n /bin/cp -p "$rollback_root/legacy-helper" "$LEGACY_HELPER_PATH" 2>/dev/null \
        || rollback_failed=true
      /usr/bin/sudo -n /usr/bin/cmp -s "$rollback_root/legacy-helper" "$LEGACY_HELPER_PATH" 2>/dev/null \
        || rollback_failed=true
    else
      /usr/bin/sudo -n /bin/rm -f "$LEGACY_HELPER_PATH" 2>/dev/null || rollback_failed=true
      /usr/bin/sudo -n /bin/test ! -e "$LEGACY_HELPER_PATH" 2>/dev/null || rollback_failed=true
    fi

    /bin/rm -rf "$APP_BUNDLE" || rollback_failed=true
    if [[ "$had_app" == "true" ]]; then
      /usr/bin/ditto "$build_tmp/previous.app" "$APP_BUNDLE" 2>/dev/null || rollback_failed=true
      /usr/bin/diff -qr "$build_tmp/previous.app" "$APP_BUNDLE" >/dev/null 2>&1 || rollback_failed=true
    elif [[ -e "$APP_BUNDLE" ]]; then
      rollback_failed=true
    fi
    /bin/rm -f "$LAUNCH_AGENT" || rollback_failed=true
    if [[ "$had_launch_agent" == "true" ]]; then
      /bin/cp -p "$build_tmp/previous-launch-agent.plist" "$LAUNCH_AGENT" 2>/dev/null \
        || rollback_failed=true
      /usr/bin/cmp -s "$build_tmp/previous-launch-agent.plist" "$LAUNCH_AGENT" 2>/dev/null \
        || rollback_failed=true
      /bin/launchctl bootstrap "gui/$CURRENT_UID" "$LAUNCH_AGENT" 2>/dev/null \
        || rollback_failed=true
      /bin/launchctl enable "gui/$CURRENT_UID/$LABEL" 2>/dev/null \
        || rollback_failed=true
    elif [[ -e "$LAUNCH_AGENT" ]]; then
      rollback_failed=true
    fi

    if [[ "$rollback_failed" == "true" ]]; then
      /usr/bin/printf '警告：自动回滚未完整通过校验。请不要继续使用当前安装，并检查应用、helper、sudoers 与 LaunchAgent。\n' >&2
      status=70
    fi
  fi

  [[ -n "$sudoers_tmp" ]] && /bin/rm -f "$sudoers_tmp"
  [[ -n "$rollback_root" ]] && /usr/bin/sudo -n /bin/rm -rf "$rollback_root" 2>/dev/null || true
  [[ -n "$build_tmp" ]] && /bin/rm -rf "$build_tmp"

  exit "$status"
}
trap cleanup EXIT

/bin/mkdir -p "$HOME/Applications" "$LOG_DIR" "$HOME/Library/LaunchAgents"

cd "$ROOT_DIR"
BUILT_APP="$("$ROOT_DIR/scripts/build-app.sh" "$build_tmp/$APP_NAME.app")"

# 在修改系统文件前一次性确认管理员权限，避免安装到一半才失败。
/usr/bin/sudo -v
rollback_root="$(/usr/bin/sudo /usr/bin/mktemp -d /private/tmp/capsomnia-install-rollback.XXXXXX)"

if [[ -d "$APP_BUNDLE" ]]; then
  had_app=true
  /usr/bin/ditto "$APP_BUNDLE" "$build_tmp/previous.app"
fi
if [[ -f "$LAUNCH_AGENT" ]]; then
  had_launch_agent=true
  /bin/cp -p "$LAUNCH_AGENT" "$build_tmp/previous-launch-agent.plist"
fi
if /usr/bin/sudo /bin/test -e "$HELPER_PATH"; then
  had_helper=true
  /usr/bin/sudo /bin/cp -p "$HELPER_PATH" "$rollback_root/helper"
fi
if /usr/bin/sudo /bin/test -e "$LEGACY_HELPER_PATH"; then
  had_legacy_helper=true
  /usr/bin/sudo /bin/cp -p "$LEGACY_HELPER_PATH" "$rollback_root/legacy-helper"
fi
if /usr/bin/sudo /bin/test -e "$SUDOERS_PATH"; then
  had_sudoers=true
  /usr/bin/sudo /bin/cp -p "$SUDOERS_PATH" "$rollback_root/sudoers"
fi
install_started=true

/bin/launchctl bootout "gui/$CURRENT_UID" "$LAUNCH_AGENT" 2>/dev/null || true
/usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true
for _ in {1..40}; do
  /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
  /bin/sleep 0.1
done
if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  /usr/bin/pkill -KILL -x "$APP_NAME" 2>/dev/null || true
fi

/bin/rm -rf "$APP_BUNDLE"
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"
/bin/rm -rf "$LEGACY_APP_BUNDLE"

/usr/bin/sudo /bin/mkdir -p "$(/usr/bin/dirname "$HELPER_PATH")" "$(/usr/bin/dirname "$SUDOERS_PATH")"
/usr/bin/sudo /usr/sbin/chown root:wheel "$(/usr/bin/dirname "$HELPER_PATH")" "$(/usr/bin/dirname "$SUDOERS_PATH")"
/usr/bin/sudo /bin/chmod 0755 "$(/usr/bin/dirname "$HELPER_PATH")" "$(/usr/bin/dirname "$SUDOERS_PATH")"
/usr/bin/sudo /usr/bin/install -o root -g wheel -m 0755 ".build/release/capsomnia-pmset" "$HELPER_PATH"
/usr/bin/sudo /bin/rm -f "$LEGACY_HELPER_PATH"

sudoers_tmp="$(/usr/bin/mktemp)"
/bin/cat > "$sudoers_tmp" <<EOF
# Capsomnia 只能切换睡眠状态、关闭显示器或立即睡眠，不能以 root 执行其他命令。
$CURRENT_USER ALL=(root) NOPASSWD: $HELPER_PATH on, $HELPER_PATH off, $HELPER_PATH display-sleep, $HELPER_PATH sleep-now
EOF

/usr/sbin/visudo -cf "$sudoers_tmp"
/usr/bin/sudo /usr/bin/install -o root -g wheel -m 0440 "$sudoers_tmp" "$SUDOERS_PATH"

/bin/cat > "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$APP_BUNDLE/Contents/MacOS/$APP_NAME</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>

  <key>ThrottleInterval</key>
  <integer>10</integer>

  <key>StandardOutPath</key>
  <string>$LOG_DIR/stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$LOG_DIR/stderr.log</string>
</dict>
</plist>
EOF

/usr/bin/plutil -lint "$LAUNCH_AGENT" >/dev/null
/bin/launchctl bootstrap "gui/$CURRENT_UID" "$LAUNCH_AGENT"
/bin/launchctl enable "gui/$CURRENT_UID/$LABEL"
/bin/launchctl print "gui/$CURRENT_UID/$LABEL" >/dev/null

install_completed=true
/usr/bin/printf 'Capsomnia 已安装并启动。“合盖时保持开机状态”打开时持续运行，关闭时恢复正常休眠。\n'
