#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
version="$(cat VERSION)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
if [[ "$version" != "$plist_version" ]]; then
  echo "VERSION and Info.plist must contain the same version." >&2
  exit 1
fi
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
bundle="dist/EjectDock.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_dir/EjectDock" "$bundle/Contents/MacOS/EjectDock"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
ditto "$bin_dir/EjectDock_EjectDock.bundle" "$bundle/Contents/Resources/EjectDock_EjectDock.bundle"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
echo "Local bundle: $bundle ($version)"
