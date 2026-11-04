# EjectDock

A macOS menu bar utility for unmounting selected drives before unplugging a dock.

Open source under the [MIT license](LICENSE).
Repository: [wasabeehq/eject-dock](https://github.com/wasabeehq/eject-dock).

Current status: local functional implementation, with hardware and distribution
acceptance checks still pending. The application discovers eligible external
disks and disk images, remembers selected disks, and performs normal unmounting
with explicit per-target results.

## Development

Requirements: macOS 13 or later, Swift 5.9 or later, the macOS SDK, and Apple
developer tools. No external dependencies. Builds target the host Mac's
architecture.

```sh
git clone https://github.com/wasabeehq/eject-dock.git
cd eject-dock
./scripts/test.sh
./scripts/build.sh
open dist/EjectDock.app
```

An eject icon appears in the menu bar, with no permanent Dock icon. When no
selection is configured, every click opens the panel. Otherwise a right click
or Control + click unmounts the configured target. The target can be the saved disk selection or an identified
USB dock subtree. A dock action resolves every currently connected member of
that proven subtree at operation time, including disks connected after the
choice was saved. A plain left click and
Option + click always open the graphical panel. Each physical disk has a
selection toggle, mount status, and a direct unmount button. Saved disconnected
selections remain visible and can be removed by turning their toggle off. Disk
images have a separate group with an option to include them in the selected-disk
action. Language and launch at login settings expand within the same panel.

```sh
./scripts/install.sh
open "$HOME/Applications/EjectDock.app"
./scripts/archive.sh
```

Installation defaults to `~/Applications`. Pass a different destination directory
as the script's first argument if needed. Quit the application before replacing
it. The ad hoc signature and local ZIP are intended for development on this Mac.
They are not a notarized Developer ID distribution.

## Project structure

- `Sources/EjectDock`: application lifecycle, AppKit menu, and Disk Arbitration observer.
- `Sources/EjectDockCore`: models and logic independent of system APIs.
- `Tests/EjectDockCoreTests`: topology, identity, preferences, gestures, and operation-state tests.
- `Resources`: application bundle metadata.
- `scripts`: tests, locally signed bundle, installation, and archive creation.
- `docs/PLAN.md`: the full project plan, translated into English for reference.
- `docs/ROADMAP.md`: phases, decisions, and technical limitations.
- `docs/VALIDATION.md`: completed checks and scenarios still requiring testing.
- `docs/LOCALIZATION.md`: language settings and translation guidelines.
- `docs/MANUAL_TESTS.md`: numbered acceptance checklist.
- `docs/DISTRIBUTION.md`: signing, release, and Homebrew preparation.
- `AGENTS.md`: project development and validation rules.

Inventory uses structured `diskutil` and `hdiutil` metadata, refreshed off the
main thread in response to Disk Arbitration events. APFS volumes are grouped
under their physical store. Multi-store APFS, internal/system media, unknown
topology, and missing or colliding identities are disabled. Partition UUIDs and
hardware metadata identify physical targets across reconnections; BSD names are
session-only. Reformatting or changing the enclosure can require reselection.

Each operation revalidates its target. Physical disks use normal Disk Arbitration volume-unmount requests followed by
a fresh inventory check. No physical eject request is made. The device remains
connected and can remain visible in Disk Utility with unmounted volumes. Images
use normal `hdiutil detach`. No forced unmount,
process termination, or backup cancellation is performed. A timeout stays pending
and retains the operation lock until the system responds. A dock success toast
appears only after a fresh complete inventory confirms that every current member
has no mounted volume or snapshot and no mounted external storage remains outside
the proven dock boundary. Such storage is reported but never added to the dock
operation. The toast closes automatically and does not use Notification Center.
Detailed results remain available in the panel.

Dock grouping currently requires a complete USB IORegistry subtree. Native
Thunderbolt or PCIe storage whose boundary cannot be proven is not offered as a
dock target. It remains available through the existing per-disk actions.

## Distribution

The bundle uses the stable identifier `fr.wasabee.ejectdock`. Preferences saved
by earlier builds under `fr.leo.ejectdock` are copied once on first launch. Its version is stored in
`VERSION` and `Resources/Info.plist`; the build checks that they match. The application
includes a dedicated icon; the menu bar uses native system symbols for its states.
English is the application's development language. The interface supports English
and French. Choose **Settings > Language** to follow
the system language or select a language explicitly. The selection is remembered;
the tooltip and panel update immediately.

Release scripts and CI are prepared separately from local installation. Public
distribution requires a Developer ID certificate and notarization credentials.
A cask must be generated from a verified, published archive and checksum; no
placeholder download is published. See the roadmap and distribution guide for
remaining gates.
