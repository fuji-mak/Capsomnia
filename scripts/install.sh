#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
LEGACY_INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LOG_DIR="$HOME/Library/Logs/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
HELPER_PATH="/Library/PrivilegedHelperTools/capsomnia-pmset"
LEGACY_HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"
CURRENT_USER="$(id -un)"

if [[ "$CURRENT_USER" == *[!A-Za-z0-9._-]* ]]; then
  echo "Unsupported macOS short user name for sudoers: $CURRENT_USER" >&2
  exit 64
fi

build_tmp="$(mktemp -d)"
sudoers_tmp=""
cleanup() {
  [[ -n "$sudoers_tmp" ]] && /bin/rm -f "$sudoers_tmp"
  [[ -n "$build_tmp" ]] && /bin/rm -rf "$build_tmp"
}
trap cleanup EXIT

mkdir -p "$HOME/Applications" "$LOG_DIR" "$HOME/Library/LaunchAgents"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
/usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true

cd "$ROOT_DIR"
BUILT_APP="$("$ROOT_DIR/scripts/build-app.sh" "$build_tmp/$APP_NAME.app")"
/bin/rm -rf "$APP_BUNDLE"
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"
/bin/rm -rf "$LEGACY_INSTALL_DIR"

sudo /bin/mkdir -p "$(dirname "$HELPER_PATH")" "$(dirname "$SUDOERS_PATH")"
sudo /usr/sbin/chown root:wheel "$(dirname "$HELPER_PATH")" "$(dirname "$SUDOERS_PATH")"
sudo /bin/chmod 0755 "$(dirname "$HELPER_PATH")" "$(dirname "$SUDOERS_PATH")"
sudo /usr/bin/install -o root -g wheel -m 0755 ".build/release/capsomnia-pmset" "$HELPER_PATH"
sudo /bin/rm -f "$LEGACY_HELPER_PATH"

sudoers_tmp="$(mktemp)"
cat > "$sudoers_tmp" <<EOF
# Allow Capsomnia to toggle only its fixed pmset helper.
$CURRENT_USER ALL=(root) NOPASSWD: $HELPER_PATH on, $HELPER_PATH off, $HELPER_PATH display-sleep
EOF

/usr/sbin/visudo -cf "$sudoers_tmp"
sudo /usr/bin/install -o root -g wheel -m 0440 "$sudoers_tmp" "$SUDOERS_PATH"

cat > "$LAUNCH_AGENT" <<EOF
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

/usr/bin/defaults write "$LABEL" ForceWelcomeOnNextLaunch -bool true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"
launchctl enable "gui/$(id -u)/$LABEL"

echo "Installed $APP_NAME."
