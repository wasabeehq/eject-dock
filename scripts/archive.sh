#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
archive="dist/EjectDock-$(cat VERSION)-$(uname -m)-local.zip"
ditto -c -k --sequesterRsrc --keepParent dist/EjectDock.app "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "Archive locale uniquement, signature ad hoc : $archive"
