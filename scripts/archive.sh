#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

architecture="${EJECTDOCK_ARCHS:-native}"
output_dir="${EJECTDOCK_OUTPUT_DIR:-dist}"
./scripts/build.sh

if [[ "$architecture" == "native" ]]; then
  architecture="$(uname -m)"
fi

archive="$output_dir/EjectDock-$(tr -d '[:space:]' < VERSION)-$architecture-local.zip"
ditto -c -k --sequesterRsrc --keepParent "$output_dir/EjectDock.app" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "Local archive only, ad hoc signature: $archive"
