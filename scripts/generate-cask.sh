#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 RELEASE_ARCHIVE.zip [OUTPUT.rb]" >&2
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
sed \
  -e "s/__VERSION__/$version/g" \
  -e "s/__SHA256__/$local_sha/g" \
  -e "s|__URL__|$url|g" \
  scripts/ejectdock.rb.template > "$output"

echo "Cask generated from the published archive: $output"
