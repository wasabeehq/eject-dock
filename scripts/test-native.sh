#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

executable="${1:-dist/EjectDock.app/Contents/MacOS/EjectDock}"
if [[ ! -x "$executable" ]]; then
  echo "Built executable not found: $executable" >&2
  exit 2
fi

test_root="$(mktemp -d /tmp/EjectDockTest-native.XXXXXX)"
test_root="$(cd "$test_root" && pwd -P)"
owned_mounts=()
cleanup() {
  # A successful physical adapter test leaves its image attached but unmounted.
  # Resolve owned image files again instead of retaining recyclable BSD numbers.
  if python3 - "$test_root" <<'PY'
import pathlib, plistlib, subprocess, sys
root = pathlib.Path(sys.argv[1]).resolve()
inventory = plistlib.loads(subprocess.check_output(["hdiutil", "info", "-plist"]))
for item in inventory.get("images", []):
    path = pathlib.Path(item.get("image-path", "")).resolve()
    if path.parent != root:
        continue
    device = next((e["dev-entry"] for e in item.get("system-entities", [])
                   if e.get("content-hint") == "GUID_partition_scheme"), None)
    if device is None:
        sys.exit(1)
    subprocess.run(["hdiutil", "detach", device], check=True, stdout=subprocess.DEVNULL)
PY
  then
    rm -rf "$test_root"
  else
    echo "Disposable image cleanup needs attention: $test_root" >&2
  fi
}
trap cleanup EXIT

run_case() {
  local filesystem="$1"
  local adapter="$2"
  local suffix image mount_path
  suffix="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  image="$test_root/$filesystem-$adapter-$suffix.dmg"
  mount_path="$test_root/EjectDockTest-$filesystem-$adapter-$suffix"
  mkdir -p "$mount_path"
  owned_mounts+=("$mount_path")

  hdiutil create -quiet -size 128m -fs "$filesystem" \
    -volname "EjectDockTest-$suffix" "$image"
  hdiutil attach -quiet -nobrowse -mountpoint "$mount_path" "$image"

  if [[ "$adapter" == "physical" ]]; then
    "$executable" --test-eject-image "$mount_path" --physical-adapter
  else
    "$executable" --test-eject-image "$mount_path"
  fi

  if mount | grep -Fq " on $mount_path "; then
    echo "Native test failed: image remains mounted at $mount_path" >&2
    exit 1
  fi
  echo "Native test passed: $filesystem using $adapter adapter."
}

filesystems="${TEST_FILESYSTEMS:-HFS+ APFS}"
adapters="${TEST_ADAPTERS:-image physical}"
for filesystem in $filesystems; do
  for adapter in $adapters; do
    case "$filesystem:$adapter" in
      HFS+:image|HFS+:physical|APFS:image|APFS:physical) ;;
      *)
        echo "Unsupported native test case: $filesystem using $adapter" >&2
        exit 2
        ;;
    esac
    run_case "$filesystem" "$adapter"
  done
done

echo "All disposable native image tests passed."
