#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "DEVELOPER_ID_APPLICATION is required for a distributable release." >&2
  exit 1
fi

if [[ -z "${RELEASE_TAG:-}" ]]; then
  echo "RELEASE_TAG is required for a distributable release." >&2
  exit 1
fi

if [[ -z "${NOTARYTOOL_PROFILE:-}" && ( -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ) ]]; then
  echo "Set NOTARYTOOL_PROFILE or the APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD variables." >&2
  exit 1
fi

./scripts/check-version.sh "$RELEASE_TAG"
version="$(tr -d '[:space:]' < VERSION)"
output_dir="${EJECTDOCK_OUTPUT_DIR:-dist}"
scratch_path="${EJECTDOCK_SCRATCH_PATH:-$output_dir/build/universal}"

EJECTDOCK_ARCHS=universal \
EJECTDOCK_OUTPUT_DIR="$output_dir" \
EJECTDOCK_SCRATCH_PATH="$scratch_path" \
CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
./scripts/build.sh

bundle="$output_dir/EjectDock.app"
submission="$output_dir/EjectDock-$version-notarization.zip"
archive="$output_dir/EjectDock-$version-universal.zip"

ditto -c -k --sequesterRsrc --keepParent "$bundle" "$submission"
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  xcrun notarytool submit "$submission" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
else
  xcrun notarytool submit "$submission" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
fi

xcrun stapler staple "$bundle"
xcrun stapler validate "$bundle"
codesign --verify --deep --strict --verbose=2 "$bundle"
spctl --assess --type execute --verbose=2 "$bundle"

ditto -c -k --sequesterRsrc --keepParent "$bundle" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
./scripts/verify-archive.sh "$archive"
echo "Notarized release archive: $archive"
