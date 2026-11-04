#!/bin/bash
# Explicit, opt-in release path for builds WITHOUT a Developer ID certificate.
# The archive is ad hoc signed and not notarized, so Gatekeeper blocks the first
# launch until the user approves it. This is never used as a fallback by
# scripts/release.sh, which keeps requiring Developer ID and notarization.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${RELEASE_TAG:-}" ]]; then
  echo "RELEASE_TAG is required, for example RELEASE_TAG=v$(tr -d '[:space:]' < VERSION)." >&2
  exit 1
fi

./scripts/check-version.sh "$RELEASE_TAG"
version="$(tr -d '[:space:]' < VERSION)"
output_dir="${EJECTDOCK_OUTPUT_DIR:-dist}"
scratch_path="${EJECTDOCK_SCRATCH_PATH:-$output_dir/build/universal}"

EJECTDOCK_ARCHS=universal \
EJECTDOCK_OUTPUT_DIR="$output_dir" \
EJECTDOCK_SCRATCH_PATH="$scratch_path" \
CODE_SIGN_IDENTITY="-" \
./scripts/build.sh

bundle="$output_dir/EjectDock.app"
archive="$output_dir/EjectDock-$version-universal.zip"

codesign --verify --deep --strict --verbose=2 "$bundle"
ditto -c -k --sequesterRsrc --keepParent "$bundle" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
verification="$(./scripts/verify-archive.sh "$archive")"
echo "$verification"
if ! grep -q 'signature adhoc' <<<"$verification"; then
  echo "Expected an ad hoc signature in the archive." >&2
  exit 1
fi

echo "Ad hoc release archive (not notarized, Gatekeeper approval required): $archive"
echo "Generate its cask with: ./scripts/generate-cask.sh --adhoc $archive OUTPUT.rb"
