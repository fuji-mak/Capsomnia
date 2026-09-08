#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_DIR="${PREVIEW_DIR:-$ROOT_DIR/dist/cli-preview}"
CPSM_REPO="${CPSM_REPO:-$ROOT_DIR/../cpsm}"
MACREADY_REPO="${MACREADY_REPO:-$ROOT_DIR/../MacReady}"
APP_BUNDLE="$PREVIEW_DIR/Capsomnia CLI Preview.app"
mkdir -p "$PREVIEW_DIR"
"$ROOT_DIR/scripts/build-app.sh" "$APP_BUNDLE"
if [[ -n "${TOOLS_PACKAGE_PATH:-}" ]]; then
  cp "$TOOLS_PACKAGE_PATH" "$PREVIEW_DIR/Capsomnia-Tools.pkg"
  cp "${CPSM_DIST:-$CPSM_REPO/dist}/bin/cpsm" "$PREVIEW_DIR/cpsm"
  cp "${MACREADY_DIST:-$MACREADY_REPO/dist}/bin/macready" "$PREVIEW_DIR/macready"
else
  SKIP_SIGNING=true DIST_DIR="$PREVIEW_DIR" CPSM_DIST="$PREVIEW_DIR/packages/cpsm" MACREADY_DIST="$PREVIEW_DIR/packages/macready" MACREADY_REPO="$MACREADY_REPO" "$CPSM_REPO/scripts/build-tools-pkg.sh"
  cp "$PREVIEW_DIR/packages/cpsm/bin/cpsm" "$PREVIEW_DIR/cpsm"
  cp "$PREVIEW_DIR/packages/macready/bin/macready" "$PREVIEW_DIR/macready"
fi
python3 - "$APP_BUNDLE" "$PREVIEW_DIR/Capsomnia-Tools.pkg" <<'PY'
from pathlib import Path
import plistlib, sys
app, package = map(Path, sys.argv[1:])
p = app / 'Contents/Info.plist'
with p.open('rb') as f:
    info = plistlib.load(f)
# Same settings/identity as the installed app. Only run one copy at a time.
info['CFBundleDisplayName'] = 'Capsomnia CLI Preview'
info.pop('CapsomniaCLIGuideURL', None)
info['CapsomniaToolsPackageURL'] = package.as_uri()
with p.open('wb') as f:
    plistlib.dump(info, f)
PY
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --strict "$PREVIEW_DIR/cpsm"
codesign --verify --strict "$PREVIEW_DIR/macready"
cat > "$PREVIEW_DIR/Start Preview.command" <<'START'
#!/bin/zsh
set -euo pipefail
PREVIEW_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.github.fuji-mak.capsomnia"
# Prevent launchd from immediately relaunching the installed version.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
osascript -e 'if application id "com.github.fuji-mak.capsomnia" is running then tell application id "com.github.fuji-mak.capsomnia" to quit'
for attempt in {1..30}; do
  if ! pgrep -f '/Contents/MacOS/Capsomnia$' >/dev/null; then break; fi
  sleep 0.1
done
if pgrep -f '/Contents/MacOS/Capsomnia$' >/dev/null; then
  echo 'Capsomnia is still quitting. Please try again.'
  exit 1
fi
open -a "$PREVIEW_DIR/Capsomnia CLI Preview.app" --args --show-settings
echo 'Preview started. Use the cpsm executable in this folder.'
START
cat > "$PREVIEW_DIR/Restore Installed App.command" <<'RESTORE'
#!/bin/zsh
set -euo pipefail
osascript -e 'if application id "com.github.fuji-mak.capsomnia" is running then tell application id "com.github.fuji-mak.capsomnia" to quit'
for attempt in {1..30}; do
  if ! pgrep -f '/Contents/MacOS/Capsomnia$' >/dev/null; then break; fi
  sleep 0.1
done
if pgrep -f '/Contents/MacOS/Capsomnia$' >/dev/null; then
  echo 'Capsomnia is still quitting. Please try again.'
  exit 1
fi
PLIST="/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
if [[ ! -f "$PLIST" ]]; then PLIST="$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"; fi
if [[ -f "$PLIST" ]]; then launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true; fi
open -a /Applications/Capsomnia.app
RESTORE
chmod +x "$PREVIEW_DIR/Start Preview.command" "$PREVIEW_DIR/Restore Installed App.command"
cp "$ROOT_DIR/docs/cli-local-preview.md" "$PREVIEW_DIR/README.md"
echo "$PREVIEW_DIR"
