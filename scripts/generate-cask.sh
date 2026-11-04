#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

adhoc=0
if [[ "${1:-}" == "--adhoc" ]]; then
  adhoc=1
  shift
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 [--adhoc] RELEASE_ARCHIVE.zip [OUTPUT.rb]" >&2
  echo "  --adhoc: the archive is ad hoc signed; adds Gatekeeper caveats to the cask." >&2
  exit 2
fi

archive="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
output="${2:-dist/Casks/ejectdock.rb}"
version="$(tr -d '[:space:]' < VERSION)"
repository="${GITHUB_REPOSITORY:-wasabeehq/eject-dock}"
url="https://github.com/$repository/releases/download/v$version/EjectDock-$version-universal.zip"

if [[ ! -f "$archive" ]]; then
  echo "Archive not found: $archive" >&2
  exit 1
fi

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "GITHUB_REPOSITORY must contain an owner and repository name." >&2
  exit 1
fi

# The flag must match the archive: never publish an ad hoc build as a regular
# cask, and never add ad hoc caveats to a Developer ID build.
check_dir="$(mktemp -d /tmp/ejectdock-cask-check.XXXXXX)"
ditto -x -k "$archive" "$check_dir"
signature_info="$(codesign -dv --verbose=4 "$check_dir/EjectDock.app" 2>&1 || true)"
if grep -q '^Signature=adhoc' <<<"$signature_info"; then
  archive_adhoc=1
else
  archive_adhoc=0
fi
rm -rf "$check_dir"
if [[ "$archive_adhoc" == 1 && "$adhoc" == 0 ]]; then
  echo "The archive is ad hoc signed. Pass --adhoc to generate a cask with Gatekeeper caveats." >&2
  exit 1
fi
if [[ "$archive_adhoc" == 0 && "$adhoc" == 1 ]]; then
  echo "--adhoc was given but the archive is not ad hoc signed." >&2
  exit 1
fi

local_sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
remote_archive="$(mktemp /tmp/ejectdock-cask-archive.XXXXXX.zip)"
trap 'rm -f "$remote_archive"' EXIT
if ! curl --fail --silent --show-error --location "$url" --output "$remote_archive"; then
  echo "Release URL is not available, so no cask was generated: $url" >&2
  exit 1
fi
remote_sha="$(shasum -a 256 "$remote_archive" | awk '{print $1}')"
if [[ "$local_sha" != "$remote_sha" ]]; then
  echo "Local archive and published release have different SHA-256 values." >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
if [[ "$adhoc" == 1 ]]; then
  caveats_file="scripts/ejectdock-caveats.rb.template"
else
  caveats_file="/dev/null"
fi
sed \
  -e "s/__VERSION__/$version/g" \
  -e "s/__SHA256__/$local_sha/g" \
  -e "s|__URL__|$url|g" \
  scripts/ejectdock.rb.template |
  awk -v caveats_file="$caveats_file" '
    $0 == "__CAVEATS__" {
      first = 1
      while ((getline line < caveats_file) > 0) {
        if (first) { print ""; first = 0 }
        print line
      }
      next
    }
    { print }
  ' > "$output"

echo "Cask generated from the published archive: $output"
