# Releasing Capsomnia

Capsomnia releases publish two package assets:

- `Capsomnia-<version>.pkg` for versioned downloads
- `Capsomnia.pkg` for stable `releases/latest/download/Capsomnia.pkg` links

## Version Updates

Before building a release, update:

- `resources/Info.plist`: `CFBundleShortVersionString`
- `resources/Info.plist`: `CFBundleVersion`
- `README.md`: current version
- `README.ja.md`: current version
- `CHANGELOG.md`: release entry

Never replace a published tag or release asset. If a published build needs any change, increment the version and create a new release. Enable GitHub Immutable Releases before publishing the first stable release.

Download links should point to `Capsomnia.pkg`, not a versioned asset name.

## Build

```sh
./scripts/build-pkg.sh
```

This writes a signed versioned package to `dist/Capsomnia-<version>.pkg`. Both `Capsomnia.app` and the native privileged helper are signed with the Developer ID Application identity before the installer package is signed.

CI builds the same package payload without signing and verifies that every BOM entry is owned by `root:wheel` and that no AppleDouble entries remain:

```sh
SKIP_SIGNING=true ./scripts/build-pkg.sh /tmp/capsomnia-pkg
```

## Notarize

```sh
./scripts/notarize-pkg.sh
```

This submits the versioned package to Apple, staples the accepted ticket, verifies the package, copies it to `dist/Capsomnia.pkg`, and writes `dist/SHA256SUMS.txt`.

The script uses the Keychain profile named `capsomnia-notary` by default. Override it with:

```sh
NOTARY_PROFILE=your-profile ./scripts/notarize-pkg.sh
```

## GitHub Release

After committing and tagging:

```sh
gh release create v<version> \
  dist/Capsomnia-<version>.pkg \
  dist/Capsomnia.pkg \
  dist/SHA256SUMS.txt \
  --title "Capsomnia <version>" \
  --notes-file /path/to/release-notes.md
```

Then verify:

```sh
curl -I -L https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia.pkg
spctl --assess --type install --verbose dist/Capsomnia.pkg
pkgutil --check-signature dist/Capsomnia.pkg
```
