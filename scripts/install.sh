#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${1:-$HOME/Applications}"
if pgrep -x EjectDock >/dev/null; then
  echo "Quitter EjectDock avant de remplacer l’application." >&2
  exit 1
fi
./scripts/build.sh
mkdir -p "$destination"
ditto dist/EjectDock.app "$destination/EjectDock.app"
codesign --verify --strict "$destination/EjectDock.app"
echo "Application installée : $destination/EjectDock.app"
