# EjectDock

A macOS menu bar utility for ejecting selected drives before unplugging a dock.

Open source under the [MIT license](LICENSE).
Repository: [leokun/eject-dock](https://github.com/leokun/eject-dock).

Current status: phase 1, a read-only foundation. The application displays detected
disks, their volumes, and their mount paths. Unmounting and ejection are not
implemented yet.

## Development

Requirements: macOS 13 or later, Swift 5.9 or later, the macOS SDK, and Apple
developer tools. No external dependencies. Builds target the host Mac's
architecture.

```sh
git clone https://github.com/leokun/eject-dock.git
cd eject-dock
./scripts/test.sh
./scripts/build.sh
open dist/EjectDock.app
```

An eject icon appears in the menu bar, with no permanent Dock icon. When no
selection is configured, a left click opens the menu. Right click, Option + click,
and Control + click are also handled.

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
- `Tests/EjectDockCoreTests`: observation grouping and gesture tests.
- `Resources`: application bundle metadata.
- `scripts`: tests, locally signed bundle, installation, and archive creation.
- `docs/PLAN.md`: the full project plan, translated into English for reference.
- `docs/ROADMAP.md`: phases, decisions, and technical limitations.
- `docs/VALIDATION.md`: completed checks and scenarios still requiring testing.
- `docs/LOCALIZATION.md`: language settings and translation guidelines.

Current grouping follows the topology reported by Disk Arbitration. Synthesized
APFS disks are not yet mapped to their physical stores. Disk images are not yet
classified. The menu therefore does not present any entry as a safe ejection
target. BSD names are used only within the current session.

## Distribution

The bundle uses the stable identifier `fr.leo.ejectdock`. Its version is stored in
`VERSION` and `Resources/Info.plist`; the build checks that they match. A dedicated
application icon still needs to be added; the menu bar uses a native system symbol.
English is the application's development language. The interface supports English
and French. Choose **Settings > Language** (or **Réglages > Langue**) to follow
the system language or select a language explicitly. The selection is remembered;
the tooltip updates immediately and menus use the new language when reopened.

Publishing releases and setting up the Homebrew tap are separate steps. No cask
or release publication workflow is provided until the actual archive URLs, tap
owner, and signing process are established. See the roadmap for distribution
requirements.
