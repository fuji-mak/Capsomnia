# Releasing Capsomnia

Capsomnia releases publish two package assets:

- `Capsomnia-<version>.pkg` for versioned downloads
- `Capsomnia.pkg` for stable `releases/latest/download/Capsomnia.pkg` links

The optional `Capsomnia-Tools.pkg` bundle is built and published in the
[cpsm repository](https://github.com/fuji-mak/cpsm). Publish that bundle before
the Capsomnia release that links to it. See [distribution preparation](docs/distribution.md).

## Version Updates

Before building a release, update:

- `resources/Info.plist`: `CFBundleShortVersionString`
- `resources/Info.plist`: `CFBundleVersion`
- `README.md`: current version
- `README.ja.md`: current version
- `README.zh-Hans.md`: current version
- `README.ko.md`: current version
- `docs/index.html`: JSON-LD `softwareVersion`
- `docs/ja/index.html`: JSON-LD `softwareVersion`
- `docs/zh-hans/index.html`: JSON-LD `softwareVersion`
- `docs/ko/index.html`: JSON-LD `softwareVersion`
- `CHANGELOG.md`: release entry

Never replace a published tag or release asset. If a published build needs any change, increment the version and create a new release. Enable GitHub Immutable Releases before publishing the first stable release.

Download links should point to `Capsomnia.pkg`, not a versioned asset name.

## Build

```sh
./scripts/build-pkg.sh
```

This writes a signed versioned package to `dist/Capsomnia-<version>.pkg`. Both `Capsomnia.app` and the native privileged helper are signed with the Developer ID Application identity before the installer package is signed.

CI builds the same package payload without signing and verifies that every BOM entry is owned by `root:wheel`:

```sh
SKIP_SIGNING=true ./scripts/build-pkg.sh /tmp/capsomnia-pkg
```

Signed builds place the app and helper in their final payload locations before signing. The build then expands both the unsigned and installer-signed packages with normal Installer-style metadata handling and verifies both nested Developer ID signatures.

## Notarize

```sh
./scripts/notarize-pkg.sh
```

This submits the versioned package to Apple, staples the accepted ticket, verifies the package, copies it to `dist/Capsomnia.pkg`, and writes `dist/SHA256SUMS.txt`.

The script uses the Keychain profile named `capsomnia-notary` by default. Override it with:

```sh
NOTARY_PROFILE=your-profile ./scripts/notarize-pkg.sh
```

## Install and launch acceptance

Signing, notarization, and matching checksums do not establish that a normal
user can open the installed app. Before publishing the exact candidate package:

- Inspect the final signed and stapled package BOM: every app file must be
  world-readable, every app directory world-readable and searchable, and the
  app, helper, and LaunchAgent must have the intended root ownership and modes.
- Install through the full production installer, including postinstall. Confirm
  that a non-root user can launch the app normally, not just reach its duplicate
  instance guard. Check the installed version and `cpsm doctor`.
- Verify both a fresh install and repair of an inaccessible root-owned 0700 app
  bundle. Confirm helper, sudoers, and LaunchAgent installation and startup.
- Exercise menu ON/OFF, timer set/cancel/expiry with the lid open, settings,
  and update checking. Restore the user's previous state after testing.
- Fail the release if installation, normal launch, or these checks fail. Record
  the tested commit, package SHA-256, results, and any untested hardware cases.

After publication, download the public package again and compare it with the
accepted candidate, including its package permissions. Never treat signature
or notarization acceptance alone as a successful launch check.

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
