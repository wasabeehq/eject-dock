# Roadmap

## Phase 1: foundation

- [x] Swift package, AppKit, and separate components.
- [x] Menu bar icon and gesture routing.
- [x] Observe volume appearances, disappearances, and changes.
- [x] Read-only inventory and isolated logic tests.
- [x] Build and bundle assembly scripts.
- [ ] Visually validate gestures on the Mac.

## Phase 2: primary functionality

- [ ] Capture metadata from APFS and USB test media.
- [ ] Resolve physical APFS topology, including multiple physical stores.
- [ ] Exclude internal disks, system media, and unknown types.
- [ ] Define persistent identity using UUIDs and hardware metadata.
- [ ] Reject collisions and ambiguous identities, even when names match.
- [ ] Add PreferencesStore and manage selections for disconnected disks.
- [ ] Inject native operations into EjectionService.
- [ ] Revalidate each target immediately before its operation.
- [ ] Unmount normally, then eject with system confirmation.
- [ ] Prevent concurrent requests and handle results independently.
- [ ] Keep operations pending when a timeout occurs.
- [ ] Test disconnections, busy disks, and partial failures.

## Phase 3: additional features

- [x] Settings menu with persistent System Default, English, and French options.
- [x] Localized interface strings, errors, tooltip, and accessibility label.
- [ ] Visually validate both languages and switching after installation.
- [ ] DiskImageService: structured inventory and image grouping.
- [ ] Validate `hdiutil info -plist` as a possible adapter.
- [ ] Actions for all external disks and all disk images.
- [ ] Settings menu and launch at login using SMAppService.
- [ ] Keep the option to include disk images disabled by default.
- [ ] Accessible states: ready, in progress, completed, partial, disconnected.
- [ ] Visible confirmation without notification permission.

## Phase 4: local installation

- [x] Bundle, identifier, build scripts, installation script, and local ZIP.
- [ ] Dedicated application icon.
- [ ] Verify launching from Applications and local updates.
- [ ] Verify preference retention and launch at login.

## Phase 5: distribution

- [x] Public application under the MIT license: leokun/eject-dock.
- [ ] Choose the tap and distribution architecture.
- [ ] Add macOS CI after validating the local foundation.
- [ ] Check that the tag, VERSION, and bundle version match.
- [ ] Sign with Developer ID, enable Hardened Runtime, notarize, and staple.
- [ ] Verify the final bundle, archive it, calculate SHA-256, and publish.
- [ ] Create the homebrew-tools tap and its cask using verified values.
- [ ] Test installation, upgrades, uninstallation, and explicit cleanup.

## Initial decisions

Minimum macOS version: 13. SMAppService.mainApp is available starting with macOS 13,
as verified in the local SDK header. The selected Disk Arbitration observation
APIs have been available since macOS 10.4. Actual macOS 13 compatibility still
requires testing on that version.

Swift Package Manager and AppKit are sufficient for the foundation. Swift tools
5.9 keeps the baseline simple without requiring contributors to use Swift 6.
Disk Arbitration callbacks run on the main run loop.

The observed logical topology does not establish persistent identity or prove
that a device is physical. Phase 2 must resolve both points before exposing any
ejection action. Never infer identity from a name or a BSD number alone.

No real disk ejection, remote publication, or Gatekeeper change is required for
this initial phase.
