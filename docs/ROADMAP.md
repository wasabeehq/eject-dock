# Roadmap

## Phase 1: foundation

- [x] Swift package, AppKit, and separate components.
- [x] Menu bar icon and gesture routing.
- [x] Observe volume appearances, disappearances, and changes.
- [x] Read-only inventory and isolated logic tests.
- [x] Build and bundle assembly scripts.
- [ ] Visually validate gestures on the Mac.

## Phase 2: primary functionality

- [x] Capture metadata from APFS and USB test media.
- [x] Resolve single-store physical APFS topology.
- [ ] Support coordinated ejection across multiple APFS physical stores (currently refused).
- [x] Exclude internal disks, system media, and unknown types.
- [x] Define persistent identity using UUIDs and hardware metadata.
- [x] Reject collisions and ambiguous identities, even when names match.
- [x] Add PreferencesStore and manage selections for disconnected disks.
- [x] Inject native operations into EjectionService.
- [x] Revalidate each target immediately before its operation.
- [x] Unmount physical volumes normally and verify that no volumes or snapshots remain mounted.
- [x] Prevent concurrent requests and handle results independently.
- [x] Keep operations pending when a timeout occurs.
- [x] Test disconnections and partial failures with injected operations; verify busy-image refusal natively.
- [ ] Validate physical USB busy, disconnect, and multi-device scenarios with test hardware.

## Phase 3: additional features

- [x] Settings menu with persistent System Default, English, and French options.
- [x] Localized interface strings, errors, tooltip, and accessibility label.
- [ ] Visually validate both languages and switching after installation.
- [x] DiskImageService: structured inventory and image grouping.
- [x] Validate `hdiutil info -plist` as a possible adapter.
- [x] Actions for all external disks and all disk images.
- [x] Settings menu and launch at login using SMAppService.
- [x] Keep the option to include disk images disabled by default.
- [x] Accessible states: ready, in progress, completed, partial, disconnected.
- [x] Visible confirmation without notification permission.
- [x] Select a proven USB dock subtree as the right-click target and resolve its current disks dynamically.
- [x] Show a transient dock result anchored to the menu bar icon.

## Phase 4: local installation

- [x] Bundle, identifier, build scripts, installation script, and local ZIP.
- [x] Dedicated application icon.
- [x] Verify launching from Applications and local updates.
- [x] Verify preference retention during a local update.
- [ ] Verify launch at login across a login session.

## Phase 5: distribution

- [x] Public application under the MIT license: wasabeehq/eject-dock.
- [x] Choose the tap and distribution architecture.
- [x] Add macOS CI after validating the local foundation.
- [x] Check that the tag, VERSION, and bundle version match.
- [ ] Sign with Developer ID, enable Hardened Runtime, notarize, and staple.
- [x] Verify the local bundle and universal archive, including SHA-256.
- [ ] Publish the signed and notarized final archive.
- [ ] Create the homebrew-tools tap and its cask using verified values.
- [ ] Test installation, upgrades, uninstallation, and explicit cleanup.

## Current operation scope

Physical disks are unmounted, not physically ejected. The device may remain
visible in Disk Utility. Confirmation requires a refreshed inventory showing no
mounted volumes or snapshots on the same target. Disk images still detach.
A dock request also requires a fresh complete dock inventory. Missing,
incomplete, ambiguous, or empty membership is not reported as success. Mounted
external storage outside the proven dock boundary blocks dock-ready confirmation
without being added to the operation.
Native Thunderbolt and PCIe dock boundaries are not inferred from undocumented
topology. Storage on an unproven boundary stays available only as an individual
disk target.

## Validation status

Checked implementation items do not imply every manual scenario has passed.
See `VALIDATION.md` for performed checks and `MANUAL_TESTS.md` for the numbered
acceptance checklist. The launch-at-login service and accessible states are
implemented; sign-in and VoiceOver checks still require manual validation.
CI and release workflows are authored but have not been run remotely.

The selected distribution target is a universal arm64/x86_64 bundle and the
future `wasabeehq/homebrew-tools` tap. No Developer ID certificate is installed;
notarization, release publication, and a live cask remain blocked on credentials
and a verified public archive. The cask generator refuses placeholder URLs.

## Initial decisions

Minimum macOS version: 13. SMAppService.mainApp is available starting with macOS 13,
as verified in the local SDK header. The selected Disk Arbitration observation
APIs have been available since macOS 10.4. Actual macOS 13 compatibility still
requires testing on that version.

Swift Package Manager and AppKit are sufficient for the foundation. Swift tools
5.9 keeps the baseline simple without requiring contributors to use Swift 6.
Disk Arbitration callbacks run on the main run loop.

Physical targets now require explicit external/physical metadata, partition UUID
witnesses, and supported topology. Mounted volumes require UUIDs too. A native
operation validates those witnesses again before unmount. Identity is never
inferred from a name or BSD number alone. Reformatting or changing an enclosure
may require reselection. Simultaneously connected UUID clones are refused;
indistinguishable clones presented one at a time cannot be differentiated by
metadata that is identical.

Native ejection checks use disposable disk images. No physical backup drive has
been ejected and Gatekeeper settings are unchanged.
