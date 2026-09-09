#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
version="$(cat VERSION)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
if [[ "$version" != "$plist_version" ]]; then
  echo "VERSION et Info.plist doivent porter la même version." >&2
  exit 1
fi
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
bundle="dist/EjectDock.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_dir/EjectDock" "$bundle/Contents/MacOS/EjectDock"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
echo "Bundle local : $bundle ($version)"
