#!/usr/bin/env python3
"""Exercise partial APFS unmount reporting on a disposable two-volume image."""
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import uuid

executable = str(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                             "dist/EjectDock.app/Contents/MacOS/EjectDock").resolve())
root = pathlib.Path(tempfile.mkdtemp(prefix="EjectDockTest-partial-"))
image = root / "partial.sparseimage"
name = "EjectDockTest-" + uuid.uuid4().hex[:12]
blocker = None
image_device = None

def run(*arguments):
    return subprocess.check_output(arguments)

try:
    run("hdiutil", "create", "-size", "2g", "-type", "SPARSE", "-fs", "APFS", "-volname", name, str(image))
    attachment = plistlib.loads(run("hdiutil", "attach", "-nobrowse", "-plist", str(image)))
    entities = attachment["system-entities"]
    first = next(e for e in entities if e.get("mount-point") == "/Volumes/" + name)
    image_device = next(e["dev-entry"] for e in entities if e.get("content-hint") == "GUID_partition_scheme")
    info = plistlib.loads(run("diskutil", "info", "-plist", first["dev-entry"]))
    container = info["APFSContainerReference"]
    busy_mount = pathlib.Path("/Volumes") / (name + "-busy")
    run("diskutil", "apfs", "addVolume", container, "APFS", name + "-busy")
    blocker = subprocess.Popen([sys.executable, "-u", "-c",
        "import os,sys,time; os.chdir(sys.argv[1]); f=open('busy.txt','w'); "
        "f.write('disposable test'); f.flush(); print('ready'); time.sleep(120)", str(busy_mount)],
        stdout=subprocess.PIPE, text=True)
    assert blocker.stdout.readline().strip() == "ready"
    result = subprocess.run([executable, "--test-eject-image", first["mount-point"], "--physical-adapter"],
                            capture_output=True, text=True, timeout=90)
    print(result.stdout.strip())
    assert result.returncode == 1, "Busy volume must not produce ejection success"
    assert "nativeFailure" in result.stdout and "unmountedVolumes: 1" in result.stdout, "Missing partial-unmount progress"
    assert "requestedVolumes: 2" in result.stdout, "Expected both disposable APFS volumes"
    assert not pathlib.Path(first["mount-point"]).is_mount(), "First volume should be unmounted"
    assert busy_mount.is_mount(), "Busy volume must remain mounted"
    print("Partial APFS unmount verified: first volume unmounted, busy second volume retained, failure preserved.")
finally:
    if blocker is not None:
        blocker.terminate()
        blocker.wait(timeout=5)
    if image_device:
        # Only the image created above is eligible for cleanup. Never force it.
        cleanup = subprocess.run(["hdiutil", "detach", image_device], capture_output=True)
        if cleanup.returncode != 0:
            print("Disposable image cleanup needs attention:", root, file=sys.stderr)
            sys.exit(1)
    import shutil
    shutil.rmtree(root)
