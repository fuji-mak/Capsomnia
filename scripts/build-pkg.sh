#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
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
COMPONENT_PLIST="$WORK_DIR/components.plist"
BOM_LIST="$WORK_DIR/bom-list.txt"
UNSIGNED_PKG="$DIST_DIR/$APP_NAME-$VERSION-unsigned.pkg"
SANITIZED_UNSIGNED_PKG="$WORK_DIR/$APP_NAME-$VERSION-sanitized-unsigned.pkg"
SIGNED_PKG="$DIST_DIR/$APP_NAME-$VERSION.pkg"

cleanup() {
  /bin/rm -rf "$WORK_DIR"
}
trap cleanup EXIT

/bin/mkdir -p \
  "$DIST_DIR" \
  "$PAYLOAD_ROOT/Applications" \
  "$PAYLOAD_ROOT/Library/LaunchAgents" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools" \
  "$SCRIPTS_DIR"

BUILT_APP="$("$ROOT_DIR/scripts/build-app.sh" "$WORK_DIR/$APP_NAME.app")"
/usr/bin/install -m 0755 \
  "$ROOT_DIR/.build/release/capsomnia-pmset" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"
if [[ "$SKIP_SIGNING" != "true" ]]; then
  /usr/bin/codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" "$BUILT_APP"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$BUILT_APP"
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$APP_SIGN_ID" \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"
  /usr/bin/codesign \
    --verify \
    --strict \
    --verbose=2 \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/capsomnia-pmset"
fi

/usr/bin/ditto "$BUILT_APP" "$PAYLOAD_ROOT/Applications/$APP_NAME.app"

/bin/cat > "$PAYLOAD_ROOT/Library/LaunchAgents/$LABEL.plist" <<EOF
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
</dict>
</plist>
EOF

/bin/cat > "$SCRIPTS_DIR/postinstall" <<'EOF'
#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"
SYSTEM_LAUNCH_AGENT="/Library/LaunchAgents/$LABEL.plist"

console_user="$(/usr/bin/stat -f "%Su" /dev/console 2>/dev/null || true)"
if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == "_mbsetupuser" ]]; then
  console_user="${SUDO_USER:-}"
fi

if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == *[!A-Za-z0-9._-]* ]]; then
  echo "Capsomnia installer could not determine the target user for sudoers." >&2
  exit 1
fi

console_uid="$(/usr/bin/id -u "$console_user")"
console_home="$(/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"

/bin/mkdir -p "$(dirname "$HELPER_PATH")" "$(dirname "$SUDOERS_PATH")"
/usr/sbin/chown root:wheel "$(dirname "$HELPER_PATH")" "$(dirname "$SUDOERS_PATH")"
/bin/chmod 0755 "$(dirname "$HELPER_PATH")" "$(dirname "$SUDOERS_PATH")"
/usr/sbin/chown root:wheel "$HELPER_PATH" "$SYSTEM_LAUNCH_AGENT"
/bin/chmod 0755 "$HELPER_PATH"
/bin/chmod 0644 "$SYSTEM_LAUNCH_AGENT"
/usr/sbin/chown -R root:wheel "/Applications/$APP_NAME.app"
/bin/chmod -R go-w "/Applications/$APP_NAME.app"
/bin/rm -f "$LEGACY_HELPER_PATH"

sudoers_tmp="$(/usr/bin/mktemp)"
cleanup() {
  /bin/rm -f "$sudoers_tmp"
}
trap cleanup EXIT

cat > "$sudoers_tmp" <<SUDOERS
# Allow Capsomnia to toggle only its fixed pmset helper.
$console_user ALL=(root) NOPASSWD: $HELPER_PATH on, $HELPER_PATH off, $HELPER_PATH display-sleep
SUDOERS

/usr/sbin/visudo -cf "$sudoers_tmp"
/usr/bin/install -o root -g wheel -m 0440 "$sudoers_tmp" "$SUDOERS_PATH"

if [[ -n "$console_home" ]]; then
  legacy_user_agent="$console_home/Library/LaunchAgents/$LABEL.plist"
  /bin/launchctl bootout "gui/$console_uid" "$legacy_user_agent" 2>/dev/null || true
  /bin/rm -f "$legacy_user_agent"
fi

/bin/launchctl bootout "gui/$console_uid" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null || true
/bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" /usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true
/bin/sleep 1
/usr/bin/sudo -u "$console_user" /usr/bin/defaults write "$LABEL" ForceWelcomeOnNextLaunch -bool true 2>/dev/null || true
/bin/launchctl bootstrap "gui/$console_uid" "$SYSTEM_LAUNCH_AGENT" 2>/dev/null || true
/bin/launchctl enable "gui/$console_uid/$LABEL" 2>/dev/null || true

exit 0
EOF

/bin/chmod 0755 "$SCRIPTS_DIR/postinstall"

/usr/bin/xattr -cr "$PAYLOAD_ROOT" "$SCRIPTS_DIR"
/usr/bin/find "$PAYLOAD_ROOT" -name '._*' -type f -delete

/usr/bin/env COPYFILE_DISABLE=true /usr/bin/pkgbuild --analyze --root "$PAYLOAD_ROOT" "${PKGBUILD_FILTERS[@]}" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleOverwriteAction upgrade" "$COMPONENT_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :0:BundleOverwriteAction string upgrade" "$COMPONENT_PLIST"

/usr/bin/env COPYFILE_DISABLE=true /usr/bin/pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --scripts "$SCRIPTS_DIR" \
  --component-plist "$COMPONENT_PLIST" \
  "${PKGBUILD_FILTERS[@]}" \
  --identifier "$LABEL.pkg" \
  --version "$VERSION" \
  --install-location "/" \
  --min-os-version "14.0" \
  "$UNSIGNED_PKG"

EXPANDED_PKG="$WORK_DIR/expanded-pkg"
PAYLOAD_ARCHIVE="$WORK_DIR/payload.cpio.gz"
/usr/sbin/pkgutil --expand-full "$UNSIGNED_PKG" "$EXPANDED_PKG"
/usr/bin/xattr -cr "$EXPANDED_PKG/Payload" "$EXPANDED_PKG/Scripts"
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
