#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
swift test
