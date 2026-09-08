#!/bin/zsh
# After author approval only. Uploads packages to Apple, not to GitHub.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${1:-$ROOT_DIR/dist/distribution}"
DIST_DIR="$(cd "$DIST_DIR" && pwd)"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to the existing notarytool keychain profile}"
export CPSM_REPO="${CPSM_REPO:-$ROOT_DIR/../cpsm}"
export MACREADY_REPO="${MACREADY_REPO:-$ROOT_DIR/../MacReady}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/resources/Info.plist")"
candidate="$DIST_DIR/capsomnia/Capsomnia-$VERSION.pkg"
pkgutil --check-signature "$candidate"
xcrun notarytool submit "$candidate" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$candidate"
xcrun stapler validate "$candidate"
spctl --assess --type install --verbose=2 "$candidate"
cp "$candidate" "$DIST_DIR/capsomnia/Capsomnia.pkg"
DIST_DIR="$DIST_DIR/cpsm" "$CPSM_REPO/scripts/notarize-pkg.sh"
DIST_DIR="$DIST_DIR/cpsm" "$CPSM_REPO/scripts/notarize-tools-pkg.sh"
DIST_DIR="$DIST_DIR/macready" "$MACREADY_REPO/scripts/notarize-pkg.sh"
(cd "$DIST_DIR/capsomnia" && shasum -a 256 "Capsomnia-$VERSION.pkg" Capsomnia.pkg > SHA256SUMS.txt)
(cd "$DIST_DIR" && shasum -a 256 capsomnia/Capsomnia.pkg cpsm/Capsomnia-Tools.pkg cpsm/cpsm.pkg macready/MacReady.pkg > SHA256SUMS.txt)
if [[ -d "$DIST_DIR/preview" ]]; then
  cp "$DIST_DIR/cpsm/Capsomnia-Tools.pkg" "$DIST_DIR/preview/Capsomnia-Tools.pkg"
fi
echo 'Notarization complete; nothing has been published to GitHub.'
