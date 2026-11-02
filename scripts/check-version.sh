#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < VERSION)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
expected_tag="${1:-}"
if [[ -z "$expected_tag" && "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    expected_tag="${GITHUB_REF_NAME:-}"
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must contain a semantic version, found: $version" >&2
    exit 1
fi

if [[ "$version" != "$plist_version" ]]; then
    echo "VERSION ($version) and CFBundleShortVersionString ($plist_version) do not match." >&2
    exit 1
fi

if [[ ! "$bundle_version" =~ ^[1-9][0-9]*$ ]]; then
    echo "CFBundleVersion must be a positive integer, found: $bundle_version" >&2
    exit 1
fi

if [[ -n "$expected_tag" && "$expected_tag" != "v$version" ]]; then
    echo "Release tag ($expected_tag) must match VERSION (v$version)." >&2
    exit 1
fi

echo "Version metadata is consistent: $version (build $bundle_version)."
