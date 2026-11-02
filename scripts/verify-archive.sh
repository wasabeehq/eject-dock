#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 ARCHIVE.zip" >&2
  exit 2
fi

archive="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
if [[ ! -f "$archive" ]]; then
  echo "Archive not found: $archive" >&2
  exit 1
fi

work_dir="$(mktemp -d /tmp/ejectdock-verify.XXXXXX)"
trap 'rm -rf "$work_dir"' EXIT
ditto -x -k "$archive" "$work_dir"
bundle="$work_dir/EjectDock.app"

test -x "$bundle/Contents/MacOS/EjectDock"
test -f "$bundle/Contents/Resources/AppIcon.icns"
plutil -lint "$bundle/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$bundle"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
architectures="$(lipo -archs "$bundle/Contents/MacOS/EjectDock")"
signature="$(codesign -dv --verbose=4 "$bundle" 2>&1 | sed -n 's/^Signature=//p')"
checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"

echo "Archive verified: version $version, architectures $architectures, signature $signature"
echo "SHA-256: $checksum"
