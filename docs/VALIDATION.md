# Validation

Checks updated on September 23, 2026, on an Apple Silicon Mac running macOS 27.
Swift 6.3.3 and the macOS 26.5 SDK are selected through Command Line Tools.

## Automated checks completed

- Full application build and `./scripts/test.sh`: 53 tests passed, zero failures.
- Topology fixtures cover internal/unknown media, missing metadata, UUID
  collisions, changed BSD names, APFS grouping, system volumes/snapshots,
  unsupported multi-store containers, and protected/user disk images.
- A sanitized fixture captured from the connected USB/APFS disk verifies actual
  metadata shape, physical grouping, and partition/volume identity witnesses.
- Operation tests cover repeated requests, revalidation, independent partial
  results, disappearance, pending timeouts, late callbacks, and old timers.
- Preferences tests cover restart persistence, disconnected selections,
  corrupted values, duplicate identities, and image inclusion disabled by default.
- English and French have 88 matching localization keys; property lists parse.
- Native and universal release builds, ad hoc signatures, bundle property lists,
  extracted archives, architectures, and SHA-256 checks are verified locally.
- The dedicated application icon was generated and visually inspected.
- Version/tag guards reject mismatched version metadata.

## Native operations completed

Disposable test images were created specifically for validation. No physical
USB or backup drive was unmounted or ejected.

- HFS+ image: normal `hdiutil detach` succeeded; absence verified afterward.
- HFS+ image: Disk Arbitration volume unmount, whole unmount, and eject succeeded;
  absence verified afterward.
- APFS image: both adapters succeeded; absence verified afterward.
- Busy HFS+ image: a disposable process held a file and working directory open.
  Disk Arbitration refused normal unmount with status 49168 and the mount was
  still present. After releasing that test process, a later retry succeeded and
  absence was verified. No force flag was used.
- Native test scripts operate on generated image mount paths only. The physical
  adapter diagnostic explicitly accepts only an eligible disposable image.

Run the reproducible image suite with:

```sh
./scripts/test-native.sh
```

Do not run multiple native suites at the same time. Discovery intentionally
fails closed if media disappears while a multi-command snapshot is collected.
This was observed during overlapping test-image activity; a fresh stable
inventory recovered successfully.

## Installation checks completed

- Installed the final native bundle at `~/Applications/EjectDock.app`.
- Launched it and observed its running process.
- Starting its executable again exited successfully without creating another
  active application instance. A per-user kernel lock guards the normal app.
- Reinstalled the same version through the staged update path, then relaunched.
- Compared exported application preferences before and after update: identical.
  The existing English language choice was retained.
- The app remains installed and running for manual acceptance testing.

## Visual and hardware checks still needed

The desktop inspection tool timed out when selecting this menu-bar-only app.
A running process does not establish that the menu renders or gestures work.
The user previously confirmed both click types opened the foundation menu and
language switching worked; the expanded interface still requires acceptance.

Use the numbered checklist in `MANUAL_TESTS.md` for:

- Actual menu gestures, language switching, About, and result presentation.
- Physical external-disk ejection, reconnection, multiple volumes and targets.
- Real hardware busy/disconnect scenarios and responsiveness during operations.
- Launch-at-login approval and a subsequent login session.
- VoiceOver, contrast, and status interpretation without notifications.
- Actual macOS 13 and Intel execution.

## Distribution and supported topology limits

- CI and release workflows are prepared but have not run remotely.
- No valid Developer ID signing identity is installed on this Mac. Developer ID
  signing, notarization, stapling, and Gatekeeper distribution assessment are not
  validated. Local ad hoc archives are not presented as public releases.
- No release or Homebrew tap has been published by this work. The cask generator
  requires a real published archive with a matching checksum before producing a
  cask. Homebrew install/upgrade/uninstall/zap remain untested.
- Multi-store APFS, missing identity witnesses, unknown topology, and protected
  media are deliberately ineligible. Multi-store support remains on the roadmap.
- Reformatting or changing the enclosure may require reselection. Simultaneous
  UUID clones are rejected; clones with identical available metadata connected
  one at a time cannot be distinguished by that metadata.

## Partial-unmount reporting correction

A manual Data_1To attempt returned Mach-encoded EBUSY (49168) after the volume
was no longer mounted, while the physical disk remained present. The previous
message did not distinguish successful unmount steps from confirmed ejection.
The exact failing step of that historical attempt was not recorded.

Native failures now preserve the step (volume unmount, whole-disk unmount, or
physical ejection), the system code, and completed unmounts. Busy errors are
localized. Partial progress is explicitly shown without claiming full ejection.
The failure stage is also written to the local system log.

`python3 scripts/test-partial-unmount.py .build/debug/EjectDock` passed using a
new disposable two-volume APFS sparse image: the first volume was unmounted,
the busy second volume remained mounted, and the returned failure preserved
1/2 completed unmounts and code 49168. Test media was cleaned up without force.
The disk-specific refusal still needs a new manual attempt with this version.

## Unmount-only scope

The user clarified that physical hardware ejection is not required. Physical
operations now stop after normal volume unmount callbacks and a fresh topology
check. Success requires the same eligible target to remain present, with no
mounted volumes or snapshots. DADiskEject and the redundant final whole-disk
unmount call have been removed. Mounted snapshots, remounts, missing targets,
and ambiguous identity prevent success confirmation.

The earlier physical-ejection diagnostics above describe the previous version.
The current native image suite checks that the physical adapter leaves its
backing device present with volumes unmounted. The image adapter still detaches.
Disk display names also retain the data-volume name after unmount instead of
falling back to the EFI partition.

## Graphical right-click panel (2026-09-10)

The nested disk menus have been replaced with a native popover containing
physical disk selection switches, mount status, direct per-target actions,
an image group, and inline settings. Operation services are unchanged.

All 41 automated tests passed, and a separate code review found no actionable
operation-wiring regressions. The local release build and archive passed. The installed executable matches
the rebuilt bundle and launches successfully. Desktop inspection timed out
when accessing the menu bar application, so visual appearance, switch clicks,
keyboard navigation, and popover dismissal remain manual checks. No physical
disk operation was performed for this interface change.

## Dock target and transient result (2026-09-23)

The panel can choose the saved disk set or one discovered dock as the left-click
target. Dock membership is resolved from a fresh inventory during the operation,
and the dock result is successful only after another complete inventory confirms
that every current member has no mounted volume or snapshot. Empty, missing,
incomplete, and ambiguous dock inventories fail closed. Mounted external storage
outside the proven boundary also blocks the ready result. Its names remain in the
panel, and the dock action never expands to unmount it.

Discovery currently exposes only complete USB IORegistry subtrees as dock
targets. It fails closed for native Thunderbolt and PCIe storage when a stable,
complete dock boundary cannot be established. Those disks remain individual
targets and are never absorbed into a USB dock operation.

The application includes a nonactivating AppKit toast anchored below the menu bar
icon on its current screen. It closes after about four seconds, has no controls,
and does not use Notification Center. The success text is emitted only for the
single confirmed dock result; failures use a brief toast while detailed results
remain in the panel. A bounded `--preview-toast` mode exercises the visual without
reading inventory, changing preferences, or performing disk operations.

`swift build --target EjectDock` passed. `./scripts/test.sh` passed all 53 tests,
including dock topology, dynamic arrival, timeout, persistence, and the typed
remaining-storage blocker. The English and French string tables parse and
contain the same 88 keys. The success toast preview ran to its bounded automatic
exit without starting inventory or disk operations, but the desktop inspection
tool timed out when binding both the unbundled executable and the built
menu-bar-only application to capture the overlay. `./scripts/archive.sh` passed
and produced `dist/EjectDock.app`.

Dock discovery on real hardware, dynamic membership during an operation,
multi-screen placement, VoiceOver behavior, and the final installed appearance
still require manual validation. No physical disk was unmounted for this change.
