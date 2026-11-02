# Distribution

EjectDock uses one universal macOS archive containing arm64 and x86_64 code. A
single release URL and SHA-256 therefore serves Apple Silicon and Intel Macs.
The local universal build has been validated with Swift Package Manager on an
Apple Silicon Mac. Actual launch compatibility still needs testing on Intel and
macOS 13 hardware.

## Local artifacts

Local bundles use an ad hoc signature and are intended only for development on
the Mac that built them:

```sh
./scripts/archive.sh
```

Build and inspect a universal local archive without publishing it:

```sh
EJECTDOCK_ARCHS=universal ./scripts/archive.sh
./scripts/verify-archive.sh dist/EjectDock-0.1.0-universal-local.zip
```

The archive script writes a sibling `.sha256` file. The verification script
extracts the bundle into a temporary directory, validates its property list and
code signature, reports its architectures, and calculates the archive checksum.

The build refuses to replace its output bundle while an EjectDock process is
running from that path. The installer also refuses to run while any EjectDock
process is active. During an update it checks the existing bundle identifier,
refuses a downgrade by default, stages the replacement, and verifies the
installed version. Ordinary updates and uninstalls preserve UserDefaults.

## Version rules

`VERSION` and `CFBundleShortVersionString` must contain the same `MAJOR.MINOR.PATCH`
value. `CFBundleVersion` must be a positive integer. A release tag must be the
same version prefixed by `v`:

```sh
./scripts/check-version.sh v0.1.0
```

CI runs tests on current GitHub hosted Apple Silicon and Intel macOS runner
labels. It also validates application icon generation, creates an ad hoc
universal archive, and verifies its signature and architectures. This validates
the packaging path but does not make the CI artifact suitable for distribution.

## Developer ID and notarization

A public download must use a Developer ID Application certificate, Hardened
Runtime, Apple notarization, and a stapled ticket. Apple documents this flow in
[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [Configuring the hardened runtime](https://developer.apple.com/documentation/xcode/configuring-the-hardened-runtime).

No Developer ID Application identity is currently installed on the development
Mac. `scripts/release.sh` therefore fails before building unless a signing
identity and notarization credentials are explicitly supplied. It never falls
back to an ad hoc signature for a distribution archive.

For local release validation, store notarization credentials in a keychain
profile and run:

```sh
xcrun notarytool store-credentials ejectdock-notary
DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)" \
NOTARYTOOL_PROFILE=ejectdock-notary \
RELEASE_TAG=v0.1.0 \
./scripts/release.sh
```

The script builds universal code, signs with timestamping and Hardened Runtime,
submits the temporary ZIP to `notarytool`, staples and validates the ticket,
checks Gatekeeper assessment, creates the final ZIP, writes its SHA-256, and
verifies the archive again.

The manual Release workflow performs the same process on GitHub Actions. It
requires these repository secrets:

- `DEVELOPER_ID_CERTIFICATE_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `DEVELOPER_ID_APPLICATION`
- `BUILD_KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

The workflow defaults to uploading an Actions artifact without creating a
release. Its explicit `publish_release` input must be enabled to create a GitHub
release. No release is published merely by pushing a tag.

## Homebrew tap

The distribution architecture uses the public application repository
`wasabeehq/eject-dock` for versioned GitHub Releases and a separate public
`wasabeehq/homebrew-tools` tap containing `Casks/ejectdock.rb`.

The cask generator refuses to create a cask until the release URL exists. It
downloads that URL and requires its SHA-256 to match the local final archive:

```sh
./scripts/generate-cask.sh \
  dist/EjectDock-0.1.0-universal.zip \
  ../homebrew-tools/Casks/ejectdock.rb
```

This prevents publishing placeholder URLs or unverified hashes. The generated
cask installs `EjectDock.app`, requires macOS 13 or later, preserves preferences
during ordinary uninstall, and removes preferences only with an explicit zap.

Once a signed and notarized release and the tap exist, validate the complete
flow on a disposable test installation:

```sh
brew tap wasabeehq/tools
brew install --cask ejectdock
brew upgrade --cask ejectdock
brew uninstall --cask ejectdock
brew uninstall --cask --zap ejectdock
```

Publishing the GitHub release, creating the tap repository, and adding signing
secrets remain external steps. Do not claim a public distribution is ready until
the downloaded archive passes `codesign`, `spctl`, stapler validation, launch
testing, and the full Homebrew lifecycle.
