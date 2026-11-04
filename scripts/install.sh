#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${1:-$HOME/Applications}"

if pgrep -x EjectDock >/dev/null; then
  echo "Quit EjectDock before replacing the application." >&2
  exit 1
fi

./scripts/check-version.sh
./scripts/build.sh
build_output="${EJECTDOCK_OUTPUT_DIR:-dist}"
new_bundle="$build_output/EjectDock.app"
new_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$new_bundle/Contents/Info.plist")"
target="$destination/EjectDock.app"

version_is_less() {
  local left_major left_minor left_patch right_major right_minor right_patch
  IFS=. read -r left_major left_minor left_patch <<< "$1"
  IFS=. read -r right_major right_minor right_patch <<< "$2"
  if (( left_major != right_major )); then
    (( left_major < right_major ))
    return
  fi
  if (( left_minor != right_minor )); then
    (( left_minor < right_minor ))
    return
  fi
  (( left_patch < right_patch ))
}

if [[ -d "$target" ]]; then
  installed_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$installed_identifier" != "fr.wasabee.ejectdock" && "$installed_identifier" != "fr.leo.ejectdock" ]]; then
    echo "Refusing to replace an application with a different bundle identifier at $target." >&2
    exit 1
  fi
  installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$target/Contents/Info.plist")"
  if version_is_less "$new_version" "$installed_version" && [[ "${ALLOW_DOWNGRADE:-0}" != "1" ]]; then
    echo "Refusing to downgrade EjectDock from $installed_version to $new_version. Set ALLOW_DOWNGRADE=1 to allow it." >&2
    exit 1
  fi
  echo "Updating EjectDock from $installed_version to $new_version."
else
  echo "Installing EjectDock $new_version."
fi

mkdir -p "$destination"
staging_root="$(mktemp -d "$destination/.ejectdock-install.XXXXXX")"
backup="$destination/.EjectDock.backup.$$"
trap 'rm -rf "$staging_root"' EXIT
ditto "$new_bundle" "$staging_root/EjectDock.app"
codesign --verify --deep --strict "$staging_root/EjectDock.app"

if [[ -d "$target" ]]; then
  mv "$target" "$backup"
fi
if ! mv "$staging_root/EjectDock.app" "$target"; then
  if [[ -d "$backup" ]]; then
    mv "$backup" "$target"
  fi
  echo "Installation failed; the previous application was restored." >&2
  exit 1
fi

installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$target/Contents/Info.plist" 2>/dev/null || true)"
if [[ "$installed_version" != "$new_version" ]] || ! codesign --verify --deep --strict "$target"; then
  rm -rf "$target"
  if [[ -d "$backup" ]]; then
    mv "$backup" "$target"
  fi
  echo "Installed application verification failed; the previous application was restored." >&2
  exit 1
fi
rm -rf "$backup"
echo "Application installed and verified: $target ($installed_version)"
