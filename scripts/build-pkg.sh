#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
ROOT_DIR="$(cd "$(/usr/bin/dirname "$0")/.." && /bin/pwd)"
DIST_DIR="${1:-$ROOT_DIR/dist}"
APP_SIGN_ID="${APP_SIGN_ID:-Developer ID Application: Taketo Fujimaki (ZJZ8627852)}"
PKG_SIGN_ID="${PKG_SIGN_ID:-Developer ID Installer: Taketo Fujimaki (ZJZ8627852)}"
SKIP_SIGNING="${SKIP_SIGNING:-false}"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"
export COPYFILE_DISABLE=true
PKGBUILD_FILTERS=(
  --filter '(^|/)\.DS_Store$'
  --filter '(^|/)\.svn($|/)'
  --filter '(^|/)CVS($|/)'
  --filter '(^|/)\._'
)

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/resources/Info.plist")"
WORK_DIR="$(/usr/bin/mktemp -d)"
PAYLOAD_ROOT="$WORK_DIR/payload"
SCRIPTS_DIR="$WORK_DIR/scripts"
BOM_LIST="$WORK_DIR/bom-list.txt"
UNSIGNED_PKG="$DIST_DIR/$APP_NAME-$VERSION-cn-unsigned.pkg"
SANITIZED_UNSIGNED_PKG="$WORK_DIR/$APP_NAME-$VERSION-cn-sanitized-unsigned.pkg"
SIGNED_PKG="$DIST_DIR/$APP_NAME-$VERSION-cn.pkg"

cleanup() {
  /bin/rm -rf "$WORK_DIR"
}
trap cleanup EXIT

/bin/mkdir -p \
  "$DIST_DIR" \
  "$PAYLOAD_ROOT/Applications" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools" \
  "$SCRIPTS_DIR"

BUILT_APP="$("$ROOT_DIR/scripts/build-app.sh" "$WORK_DIR/$APP_NAME.app")"
/usr/bin/install -m 0755 \
  "$ROOT_DIR/.build/release/capsomnia-pmset" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"
if [[ "$SKIP_SIGNING" == "true" ]]; then
  # 本地构建无法获得 Apple 公证，但仍使用 ad-hoc 签名封住二进制内容。
  /usr/bin/codesign --force --options runtime --sign - \
    "$BUILT_APP/Contents/Resources/capsomnia-ai-hook"
  /usr/bin/codesign --force --options runtime --sign - "$BUILT_APP"
  /usr/bin/codesign --force --options runtime --sign - \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
    "$BUILT_APP/Contents/Resources/capsomnia-ai-hook"
  /usr/bin/codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" "$BUILT_APP"
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$APP_SIGN_ID" \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$BUILT_APP"
/usr/bin/codesign \
  --verify \
  --strict \
  --verbose=2 \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"

/usr/bin/ditto --noextattr --noqtn "$BUILT_APP" "$PAYLOAD_ROOT/Applications/$APP_NAME.app"

/bin/cat > "$SCRIPTS_DIR/postinstall" <<'EOF'
#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"
SYSTEM_LAUNCH_AGENT="/Library/LaunchAgents/$LABEL.plist"
USER_LAUNCH_AGENT=""
USER_LAUNCH_AGENT_BACKUP=""
USER_LAUNCH_AGENT_TEMPLATE=""
had_user_launch_agent=false
install_completed=false
sudoers_tmp=""
sudoers_backup=""
had_sudoers=false
console_uid=""

install_user_launch_agent_from() {
  local source_path="$1"
  local user_tmp
  user_tmp="$(/bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
    /usr/bin/mktemp "$console_home/Library/LaunchAgents/.capsomnia.XXXXXX")"
  /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
    /bin/cp "$source_path" "$user_tmp"
  /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
    /bin/chmod 0644 "$user_tmp"
  /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
    /bin/mv -f "$user_tmp" "$USER_LAUNCH_AGENT"
}

cleanup() {
  local status=$?
  local rollback_failed=false
  trap - EXIT

  if [[ "$status" -ne 0 && "$install_completed" != "true" ]]; then
    /usr/bin/printf 'Capsomnia 安装未完成，正在撤销授权与后台启动设置。\n' >&2
    if [[ -n "$console_uid" && -n "$USER_LAUNCH_AGENT" ]]; then
      /bin/launchctl bootout "gui/$console_uid" "$USER_LAUNCH_AGENT" 2>/dev/null || true
    fi
    if [[ -n "$console_uid" ]]; then
      /bin/launchctl bootout "gui/$console_uid" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null || true
    fi
    if [[ -x "$HELPER_PATH" ]]; then
      "$HELPER_PATH" off 2>/dev/null \
        || /usr/bin/pmset -a disablesleep 0 2>/dev/null \
        || rollback_failed=true
    fi
    if [[ "$had_sudoers" == "true" && -n "$sudoers_backup" ]]; then
      /bin/cp -p "$sudoers_backup" "$SUDOERS_PATH" 2>/dev/null || rollback_failed=true
      /usr/bin/cmp -s "$sudoers_backup" "$SUDOERS_PATH" 2>/dev/null || rollback_failed=true
    else
      /bin/rm -f "$SUDOERS_PATH" || rollback_failed=true
      /bin/test ! -e "$SUDOERS_PATH" || rollback_failed=true
    fi
    if [[ -n "$USER_LAUNCH_AGENT" ]]; then
      /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
        /bin/rm -f "$USER_LAUNCH_AGENT" 2>/dev/null || rollback_failed=true
      if [[ "$had_user_launch_agent" == "true" && -n "$USER_LAUNCH_AGENT_BACKUP" ]]; then
        install_user_launch_agent_from "$USER_LAUNCH_AGENT_BACKUP" 2>/dev/null || rollback_failed=true
      fi
    fi
    if [[ -n "$console_uid" && -n "$USER_LAUNCH_AGENT" && -f "$USER_LAUNCH_AGENT" ]]; then
      /bin/launchctl bootstrap "gui/$console_uid" "$USER_LAUNCH_AGENT" 2>/dev/null \
        || rollback_failed=true
      /bin/launchctl enable "gui/$console_uid/$LABEL" 2>/dev/null \
        || rollback_failed=true
    elif [[ -n "$console_uid" && -f "$SYSTEM_LAUNCH_AGENT" ]]; then
      /bin/launchctl bootstrap "gui/$console_uid" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null \
        || rollback_failed=true
      /bin/launchctl enable "gui/$console_uid/$LABEL" 2>/dev/null \
        || rollback_failed=true
    fi
    if [[ "$rollback_failed" == "true" ]]; then
      /usr/bin/printf 'Capsomnia 自动回滚未完整通过校验，请检查睡眠状态、sudoers 与 LaunchAgent。\n' >&2
      status=70
    fi
  fi

  [[ -n "$sudoers_tmp" ]] && /bin/rm -f "$sudoers_tmp"
  [[ -n "$sudoers_backup" ]] && /bin/rm -f "$sudoers_backup"
  [[ -n "$USER_LAUNCH_AGENT_BACKUP" ]] && /bin/rm -f "$USER_LAUNCH_AGENT_BACKUP"
  [[ -n "$USER_LAUNCH_AGENT_TEMPLATE" ]] && /bin/rm -f "$USER_LAUNCH_AGENT_TEMPLATE"

  exit "$status"
}
trap cleanup EXIT

console_user="$(/usr/bin/stat -f "%Su" /dev/console 2>/dev/null || true)"
if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == "_mbsetupuser" ]]; then
  console_user="${SUDO_USER:-}"
fi

if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == *[!A-Za-z0-9._-]* ]]; then
  /usr/bin/printf 'Capsomnia 无法确认要为哪个本地账户启用睡眠控制。\n' >&2
  exit 1
fi

console_uid="$(/usr/bin/id -u "$console_user")"
console_home="$(/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
if [[ -z "$console_home" || "$console_home" != /* || ! -d "$console_home" ]]; then
  /usr/bin/printf 'Capsomnia 无法确认当前账户的主目录。\n' >&2
  exit 1
fi
USER_LAUNCH_AGENT="$console_home/Library/LaunchAgents/$LABEL.plist"
USER_LOG_DIR="$console_home/Library/Logs/$APP_NAME"

/bin/mkdir -p "$(/usr/bin/dirname "$HELPER_PATH")" "$(/usr/bin/dirname "$SUDOERS_PATH")"
/usr/sbin/chown root:wheel "$(/usr/bin/dirname "$HELPER_PATH")" "$(/usr/bin/dirname "$SUDOERS_PATH")"
/bin/chmod 0755 "$(/usr/bin/dirname "$HELPER_PATH")" "$(/usr/bin/dirname "$SUDOERS_PATH")"
/usr/sbin/chown root:wheel "$HELPER_PATH"
/bin/chmod 0755 "$HELPER_PATH"
/usr/sbin/chown -R root:wheel "/Applications/$APP_NAME.app"
/bin/chmod -R go-w "/Applications/$APP_NAME.app"

sudoers_tmp="$(/usr/bin/mktemp)"
if [[ -f "$SUDOERS_PATH" ]]; then
  had_sudoers=true
  sudoers_backup="$(/usr/bin/mktemp)"
  /bin/cp -p "$SUDOERS_PATH" "$sudoers_backup"
fi
/bin/cat > "$sudoers_tmp" <<SUDOERS
# Capsomnia 只能切换睡眠状态、关闭显示器或立即睡眠，不能以 root 执行其他命令。
$console_user ALL=(root) NOPASSWD: $HELPER_PATH on, $HELPER_PATH off, $HELPER_PATH display-sleep, $HELPER_PATH sleep-now
SUDOERS

/usr/sbin/visudo -cf "$sudoers_tmp"
/usr/bin/install -o root -g wheel -m 0440 "$sudoers_tmp" "$SUDOERS_PATH"

if [[ -n "$console_home" ]]; then
  legacy_user_agent="$console_home/Library/LaunchAgents/$LABEL.plist"
  # These paths are user-controlled. Create them as the target user so a
  # malicious symlink cannot make the root installer chown a system directory.
  /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
    /bin/mkdir -p "$console_home/Library/LaunchAgents" "$USER_LOG_DIR"
  if [[ -f "$USER_LAUNCH_AGENT" ]]; then
    had_user_launch_agent=true
    USER_LAUNCH_AGENT_BACKUP="$(/usr/bin/mktemp)"
    /usr/sbin/chown "$console_user":staff "$USER_LAUNCH_AGENT_BACKUP"
    /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
      /bin/cp "$USER_LAUNCH_AGENT" "$USER_LAUNCH_AGENT_BACKUP"
    /usr/sbin/chown root:wheel "$USER_LAUNCH_AGENT_BACKUP"
    /bin/chmod 0600 "$USER_LAUNCH_AGENT_BACKUP"
  fi
  /bin/launchctl bootout "gui/$console_uid" "$legacy_user_agent" 2>/dev/null || true
fi

/bin/launchctl bootout "gui/$console_uid" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null || true
/bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" /usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true
for _ in {1..40}; do
  /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
  /bin/sleep 0.1
done
if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" /usr/bin/pkill -KILL -x "$APP_NAME" 2>/dev/null || true
fi
USER_LAUNCH_AGENT_TEMPLATE="$(/usr/bin/mktemp)"
/bin/cat > "$USER_LAUNCH_AGENT_TEMPLATE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
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
  <string>$USER_LOG_DIR/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$USER_LOG_DIR/stderr.log</string>
</dict>
</plist>
PLIST
/bin/chmod 0644 "$USER_LAUNCH_AGENT_TEMPLATE"
install_user_launch_agent_from "$USER_LAUNCH_AGENT_TEMPLATE"
/usr/bin/plutil -lint "$USER_LAUNCH_AGENT" >/dev/null
/bin/launchctl bootstrap "gui/$console_uid" "$USER_LAUNCH_AGENT"
/bin/launchctl enable "gui/$console_uid/$LABEL"
/bin/launchctl print "gui/$console_uid/$LABEL" >/dev/null
/bin/rm -f "$SYSTEM_LAUNCH_AGENT"

/bin/rm -f "$LEGACY_HELPER_PATH"
install_completed=true
exit 0
EOF

/bin/chmod 0755 "$SCRIPTS_DIR/postinstall"

/usr/bin/find "$PAYLOAD_ROOT" -name '._*' -type f -delete

/usr/bin/env COPYFILE_DISABLE=true /usr/bin/pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --scripts "$SCRIPTS_DIR" \
  "${PKGBUILD_FILTERS[@]}" \
  --identifier "$LABEL.pkg" \
  --version "$VERSION" \
  --install-location "/" \
  --min-os-version "14.0" \
  "$UNSIGNED_PKG"

EXPANDED_PKG="$WORK_DIR/expanded-pkg"
PAYLOAD_ARCHIVE="$WORK_DIR/payload.cpio.gz"
/usr/sbin/pkgutil --expand-full "$UNSIGNED_PKG" "$EXPANDED_PKG"
/bin/chmod -R u+rwX "$EXPANDED_PKG"
/usr/bin/sed -E -i '' 's/ relocatable="(true|false)"/ relocatable="false"/' "$EXPANDED_PKG/PackageInfo"
/usr/bin/grep -q ' relocatable="false"' "$EXPANDED_PKG/PackageInfo"
/usr/bin/find "$EXPANDED_PKG/Payload" -name '._*' -type f -delete
/usr/bin/lsbom "$EXPANDED_PKG/Bom" \
  | /usr/bin/awk -F '\t' 'BEGIN { OFS = "\t" } $1 !~ /(^|\/)\._/ { $3 = "0/0"; print }' \
  > "$BOM_LIST"
/usr/bin/mkbom -i "$BOM_LIST" "$EXPANDED_PKG/Bom"

payload_file_count="$(/usr/bin/lsbom -s "$EXPANDED_PKG/Bom" | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
payload_install_kbytes="$(/usr/bin/du -sk "$EXPANDED_PKG/Payload" | /usr/bin/awk '{print $1}')"
/usr/bin/sed -E -i '' \
  "s/<payload numberOfFiles=\"[0-9]+\" installKBytes=\"[0-9]+\"\\/>/<payload numberOfFiles=\"$payload_file_count\" installKBytes=\"$payload_install_kbytes\"\\/>/" \
  "$EXPANDED_PKG/PackageInfo"

(
  cd "$EXPANDED_PKG/Payload"
  /usr/bin/find . | /usr/bin/cpio -o -H odc -z -R root:wheel > "$PAYLOAD_ARCHIVE"
) 2>/dev/null
/bin/rm -rf "$EXPANDED_PKG/Payload"
/bin/mv "$PAYLOAD_ARCHIVE" "$EXPANDED_PKG/Payload"
/usr/sbin/pkgutil --flatten "$EXPANDED_PKG" "$SANITIZED_UNSIGNED_PKG"
/bin/mv -f "$SANITIZED_UNSIGNED_PKG" "$UNSIGNED_PKG"

VERIFY_PKG="$WORK_DIR/verify-pkg"
/usr/sbin/pkgutil --expand-full "$UNSIGNED_PKG" "$VERIFY_PKG"
unexpected_owner="$(/usr/bin/lsbom "$VERIFY_PKG/Bom" | /usr/bin/awk -F '\t' '$3 != "0/0" { print; exit }')"
appledouble_entry="$(/usr/bin/lsbom -s "$VERIFY_PKG/Bom" | /usr/bin/awk '$0 ~ /(^|\/)\._/ { print; exit }')"
if [[ -n "$unexpected_owner" ]]; then
  echo "Package payload contains a non-root owner: $unexpected_owner" >&2
  exit 1
fi
if [[ -n "$appledouble_entry" ]]; then
  echo "Package BOM contains an AppleDouble entry: $appledouble_entry" >&2
  exit 1
fi

if [[ "$SKIP_SIGNING" == "true" ]]; then
  echo "$UNSIGNED_PKG"
else
  /usr/bin/productsign --sign "$PKG_SIGN_ID" "$UNSIGNED_PKG" "$SIGNED_PKG"
  echo "$SIGNED_PKG"
fi
