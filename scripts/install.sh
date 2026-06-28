#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
LABEL="com.github.fuji-mak.capsomnia"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LOG_DIR="$HOME/Library/Logs/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
HELPER_PATH="/usr/local/sbin/capsomnia-pmset"
SUDOERS_PATH="/etc/sudoers.d/capsomnia"

mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"

cd "$ROOT_DIR"
/usr/bin/swift build -c release
/usr/bin/install -m 0755 ".build/release/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

sudo /usr/bin/install -o root -g wheel -m 0755 "support/capsomnia-pmset" "$HELPER_PATH"

sudoers_tmp="$(mktemp)"
cat > "$sudoers_tmp" <<EOF
# Allow Capsomnia to toggle only its fixed pmset helper.
$USER ALL=(root) NOPASSWD: $HELPER_PATH on, $HELPER_PATH off
EOF

/usr/sbin/visudo -cf "$sudoers_tmp"
sudo /usr/bin/install -o root -g wheel -m 0440 "$sudoers_tmp" "$SUDOERS_PATH"
rm -f "$sudoers_tmp"

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
    <string>$INSTALL_DIR/$APP_NAME</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$LOG_DIR/stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$LOG_DIR/stderr.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"
launchctl enable "gui/$(id -u)/$LABEL"

echo "Installed $APP_NAME."
