#!/bin/zsh
# Local artifacts only. No installation, GitHub publication, or notarization.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${1:-$ROOT_DIR/dist/distribution}"
mkdir -p "$DIST_DIR"
DIST_DIR="$(cd "$DIST_DIR" && pwd)"
export CPSM_REPO="${CPSM_REPO:-$ROOT_DIR/../cpsm}"
export MACREADY_REPO="${MACREADY_REPO:-$ROOT_DIR/../MacReady}"
export SKIP_SIGNING="${SKIP_SIGNING:-false}"
export CPSM_DIST="$DIST_DIR/cpsm"
export MACREADY_DIST="$DIST_DIR/macready"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/resources/Info.plist")"
python3 "$ROOT_DIR/scripts/sync-vendor.py" --check
python3 - "$ROOT_DIR" "$CPSM_REPO" "$MACREADY_REPO" <<'PY'
from pathlib import Path
import hashlib, json, sys
root, cpsm, macready = map(Path, sys.argv[1:])
for lib, repo in [('CapsomniaControl', cpsm), ('MacStateCore', macready)]:
    snapshot = json.loads((root/'Vendor'/lib/'snapshot.json').read_text())
    assert snapshot['version'] == (repo/'VERSION').read_text().strip(), f'{lib}: version drift; run sync-vendor.py'
    for rel, digest in snapshot['sha256'].items():
        if rel.startswith('Sources/') or rel == 'LICENSE':
            assert hashlib.sha256((repo/rel).read_bytes()).hexdigest() == digest, f'{lib}/{rel}: source drift; run sync-vendor.py'
PY
"$ROOT_DIR/scripts/build-pkg.sh" "$DIST_DIR/capsomnia"
if [[ "$SKIP_SIGNING" == true ]]; then
  cp "$DIST_DIR/capsomnia/Capsomnia-$VERSION-unsigned.pkg" "$DIST_DIR/capsomnia/Capsomnia.pkg"
else
  cp "$DIST_DIR/capsomnia/Capsomnia-$VERSION.pkg" "$DIST_DIR/capsomnia/Capsomnia.pkg"
fi
DIST_DIR="$CPSM_DIST" "$CPSM_REPO/scripts/build-tools-pkg.sh"
if [[ "$SKIP_SIGNING" != true ]]; then
  # Retain only signed product candidates in the distribution directory.
  rm -f "$DIST_DIR/capsomnia/Capsomnia-$VERSION-unsigned.pkg"
fi
(cd "$DIST_DIR" && shasum -a 256 capsomnia/Capsomnia.pkg cpsm/Capsomnia-Tools.pkg cpsm/cpsm.pkg macready/MacReady.pkg > SHA256SUMS.txt)
(cd "$DIST_DIR/capsomnia" && shasum -a 256 Capsomnia*.pkg > SHA256SUMS.txt)
cp "$ROOT_DIR/docs/distribution.md" "$DIST_DIR/README.md"
PREVIEW_DIR="$DIST_DIR/preview" TOOLS_PACKAGE_PATH="$CPSM_DIST/Capsomnia-Tools.pkg" "$ROOT_DIR/scripts/build-local-cli-preview.sh"
echo "Local distribution candidates: $DIST_DIR"
echo "Signed unless SKIP_SIGNING=true; not notarized, installed, or published."
