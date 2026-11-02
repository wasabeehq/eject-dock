#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export MACOSX_DEPLOYMENT_TARGET=13.0

./scripts/check-version.sh
version="$(tr -d '[:space:]' < VERSION)"
output_dir="${EJECTDOCK_OUTPUT_DIR:-dist}"
architectures="${EJECTDOCK_ARCHS:-native}"
sign_identity="${CODE_SIGN_IDENTITY:--}"

build_arguments=(-c release)
case "$architectures" in
  native)
    architecture_label="$(uname -m)"
    ;;
  universal)
    build_arguments+=(--arch arm64 --arch x86_64)
    architecture_label="universal"
    ;;
  arm64|x86_64)
    build_arguments+=(--arch "$architectures")
    architecture_label="$architectures"
    ;;
  *)
    echo "EJECTDOCK_ARCHS must be native, universal, arm64, or x86_64." >&2
    exit 2
    ;;
esac

if [[ -n "${EJECTDOCK_SCRATCH_PATH:-}" ]]; then
  build_arguments+=(--scratch-path "$EJECTDOCK_SCRATCH_PATH")
fi

swift build "${build_arguments[@]}"
bin_dir="$(swift build "${build_arguments[@]}" --show-bin-path)"
bundle="$output_dir/EjectDock.app"

for pid in $(pgrep -x EjectDock 2>/dev/null || true); do
  executable="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
  case "$executable" in
    "$PWD/$bundle/Contents/MacOS/EjectDock"|"$bundle/Contents/MacOS/EjectDock")
      echo "Quit the EjectDock instance running from $bundle before replacing it." >&2
      exit 1
      ;;
  esac
done

mkdir -p "$output_dir"
staging_root="$(mktemp -d "$output_dir/.ejectdock-build.XXXXXX")"
trap 'rm -rf "$staging_root"' EXIT
staging_bundle="$staging_root/EjectDock.app"
mkdir -p "$staging_bundle/Contents/MacOS" "$staging_bundle/Contents/Resources"
cp "$bin_dir/EjectDock" "$staging_bundle/Contents/MacOS/EjectDock"
cp Resources/Info.plist "$staging_bundle/Contents/Info.plist"
cp Resources/AppIcon.icns "$staging_bundle/Contents/Resources/AppIcon.icns"
ditto "$bin_dir/EjectDock_EjectDock.bundle" "$staging_bundle/Contents/Resources/EjectDock_EjectDock.bundle"

if [[ "$sign_identity" == "-" ]]; then
  codesign --force --sign - "$staging_bundle"
  signature_label="ad hoc"
else
  codesign --force --timestamp --options runtime --sign "$sign_identity" "$staging_bundle"
  signature_label="Developer ID with Hardened Runtime"
fi

codesign --verify --deep --strict --verbose=2 "$staging_bundle"
actual_architectures="$(lipo -archs "$staging_bundle/Contents/MacOS/EjectDock")"
if [[ "$architectures" == "universal" && "$actual_architectures" != *arm64* ]]; then
  echo "Universal build is missing arm64." >&2
  exit 1
fi
if [[ "$architectures" == "universal" && "$actual_architectures" != *x86_64* ]]; then
  echo "Universal build is missing x86_64." >&2
  exit 1
fi

rm -rf "$bundle"
mv "$staging_bundle" "$bundle"
echo "Bundle: $bundle ($version, $architecture_label, $signature_label)"
