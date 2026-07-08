#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if (( $# > 1 )); then
  echo "Usage: scripts/build-app.sh [output-app-path]" >&2
  exit 64
fi

REQUESTED_APP_BUNDLE="${1:-$ROOT_DIR/dist/$APP_NAME.app}"
case "$REQUESTED_APP_BUNDLE" in
  /*) APP_BUNDLE="$REQUESTED_APP_BUNDLE" ;;
  *) APP_BUNDLE="$ROOT_DIR/$REQUESTED_APP_BUNDLE" ;;
esac

if [[ "$APP_BUNDLE" != *.app ]]; then
  echo "Output path must end with .app: $APP_BUNDLE" >&2
  exit 64
fi

CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
/usr/bin/swift build -c release >&2

/bin/rm -rf "$APP_BUNDLE"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/install -m 0755 ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
/usr/bin/install -m 0644 "resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/install -m 0644 "resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/install -m 0755 "scripts/uninstall.sh" "$RESOURCES_DIR/uninstall.sh"

echo "$APP_BUNDLE"
