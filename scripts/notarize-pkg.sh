#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(/usr/bin/dirname "$0")/.." && /bin/pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/resources/Info.plist")"
PKG_PATH="${1:-$ROOT_DIR/dist/Capsomnia-$VERSION.pkg}"
NOTARY_PROFILE="${NOTARY_PROFILE:-capsomnia-notary}"
STABLE_PKG="$ROOT_DIR/dist/Capsomnia.pkg"
CHECKSUMS_PATH="$ROOT_DIR/dist/SHA256SUMS.txt"

case "$PKG_PATH" in
  /*) ;;
  *) PKG_PATH="$ROOT_DIR/$PKG_PATH" ;;
esac

if [[ ! -f "$PKG_PATH" ]]; then
  /usr/bin/printf '找不到安装包：%s\n' "$PKG_PATH" >&2
  exit 66
fi

/usr/bin/xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
/usr/bin/xcrun stapler staple "$PKG_PATH"
/usr/sbin/spctl --assess --type install --verbose "$PKG_PATH"
/usr/sbin/pkgutil --check-signature "$PKG_PATH"

/bin/cp "$PKG_PATH" "$STABLE_PKG"
(
  cd "$ROOT_DIR/dist"
  /usr/bin/shasum -a 256 "$(/usr/bin/basename "$PKG_PATH")" "$(/usr/bin/basename "$STABLE_PKG")" > "$CHECKSUMS_PATH"
)

/usr/bin/printf '%s\n' "$PKG_PATH"
/usr/bin/printf '%s\n' "$STABLE_PKG"
