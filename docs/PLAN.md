# EjectDock project

Current scope decision (September 9, 2026): physical targets are unmounted only,
with post-operation verification. Physical ejection is not required and must not
be requested. This supersedes the physical-ejection steps in the original plan
below. Disk images retain their detach action.

Create a small macOS application that ejects preselected disks with one click
before unplugging a docking station.

## 1. Purpose and scope

Primary use case:

- An external backup drive usually stays connected to the dock.
- The user selects this drive once in settings.
- A left click on the menu bar icon starts ejecting it.
- The application confirms the result before the user unplugs the dock.

The application must:

- Run exclusively in the menu bar, without a permanent Dock icon.
- Allow multiple disks to be selected for the primary action.
- Remember the selection across restarts and reconnections.
- Provide an action to eject all mounted disk images.
- Support installation and updates through Homebrew.

Do not include in the first version:

- Automatic ejection on sleep.
- Synchronization, user accounts, or telemetry.
- Built-in automatic updates.
- Windows or Linux functionality.
- Forced ejection or automatic termination of blocking processes.

## 2. Interface behavior

### Left click

Eject the selected disks that are currently connected.

- Do not request confirmation on every click.
- Ignore selected disks that are disconnected.
- Prevent concurrent operations triggered by repeated clicks.
- Open the menu if no selection has been configured.
- If a selection exists but none of its disks are connected, display an explicit
  status without ejecting any other disks.

### Right click

Open a native macOS menu.

Also support Option + click to open this menu. Verify secondary click and
Control + click behavior.

Do not use Command + click as the main alternative gesture, to preserve standard
menu bar interactions.

### Proposed menu layout

- Eject Selected Disks
- Eject All External Disks
- Eject All Disk Images
- Separator
- External Disks
  - One submenu per physical disk:
    - Status and associated volumes
    - Eject Now
    - Include in Left-Click Ejection
- Disk Images
  - One entry per mounted image:
    - Eject Now
- Separator
- Settings
- About
- Quit

Persistent selections must remain viewable and removable even when the relevant
disk is disconnected.

### Settings

- Launch at login.
- Manage selected disks, including disconnected ones.
- Disabled by default: include all disk images in the left-click action.

Start with a settings menu. Create a SwiftUI window only if it meaningfully
improves usability.

### Visual feedback

Distinguish between:

- Selected disks connected and ready to eject.
- Ejection in progress.
- Ejection completed.
- Partial result or failure.
- No selected disks connected.

Provide a tooltip and accessible labels. Do not rely on color alone to convey
status.

Success must be visible without depending on macOS notification permission.

Use accurate wording:

- "Selected disks ejected" if only the selected disks were ejected.
- Do not announce "You can unplug the dock" if other external disks remain mounted.

## 3. Technology stack

- Swift.
- AppKit for NSStatusItem, clicks, and menus.
- Optional SwiftUI for a settings window.
- Disk Arbitration to observe disks and perform native unmount and eject operations.
- UserDefaults for simple preferences.
- ServiceManagement for launch at login, depending on the minimum macOS version.
- Local logging using system tools.

Verify APIs and their availability before setting the minimum macOS version.

Do not request Accessibility or Full Disk Access permissions without a
demonstrated technical need.

## 4. Disk discovery and identification

Distinguish between:

- External physical disks.
- Volumes and partitions belonging to the same disk.
- Mounted disk images.
- Internal disks and system volumes.
- Network shares, excluded from the initial scope.

Present one ejection target per physical disk. A disk containing multiple volumes
must not appear as several independent devices to unplug.

Do not use the following as persistent identifiers:

- Display name.
- Mount path.
- BSD number alone, such as disk4.

Determine an identity strategy using metadata that is actually available: UUIDs
and relevant hardware identifiers.

Test this strategy with APFS and USB enclosures. If identity is missing,
duplicated, or ambiguous, do not automatically select a disk by name alone.

For disk images:

- Identify images that are actually mounted.
- Do not rely only on a file extension or volume name.
- Group volumes belonging to the same image.
- Provide an adapter using structured hdiutil output if necessary after
  validating the available APIs.

## 5. Ejection engine

Separate system logic from the interface.

For each request:

1. Capture the requested targets.
2. Revalidate their presence, identity, and eligibility.
3. Unmount the relevant volumes normally.
4. Eject the physical disk or detach the image.
5. Wait for the system result.
6. Refresh the inventory and present the result.

Explicitly handle:

- Busy disks.
- Backups in progress.
- Disconnection during an operation.
- Partial ejection.
- System errors.
- Operations that are slow to respond.
- Disks that are already unmounted but still connected.

Never:

- Force ejection.
- Kill a process.
- Automatically stop a backup.
- Display success before confirmation.
- Eject an internal or system disk.

If a timeout occurs, display an uncertain or pending state; do not treat the
timeout as success.

Process targets independently so that a blocked disk does not prevent reporting
results for the others.

## 6. Code organization

Use simple modules or components:

- App: lifecycle and startup.
- MenuBarController: icon, gestures, and menu construction.
- DiskInventory: observation and inventory.
- DiskIdentity: persistent identification.
- EjectionService: system operations.
- DiskImageService: image identification and detachment.
- PreferencesStore: selection and options.
- LoginItemService: launch at login.
- Models: disks, volumes, states, and results.

Inject system services to test the logic without ejecting real disks.

Avoid external dependencies until a concrete need justifies them.

## 7. Building and local installation

Start by inspecting:

- Repository instructions.
- macOS version and Mac architecture.
- Available Swift tools and macOS SDK.
- Availability of Command Line Tools or Xcode.
- Existing Git conventions.

Recommended approach:

- Swift Package Manager for compilation.
- A script to assemble EjectDock.app.
- Info.plist, an icon, and a stable bundle identifier.
- Appropriate local signing.
- An installation script targeting the chosen Applications directory.

If the required capabilities make an Xcode project more suitable, document why
and retain an automated build process.

Provide simple commands to:

- Build.
- Test.
- Install locally.
- Launch.
- Produce a distribution archive.

Do not disable Gatekeeper globally.

## 8. Homebrew distribution

Use a personal tap, without depending on acceptance into the official Homebrew
catalog.

Target structure:

- Application repository.
- homebrew-tools repository.
- Casks/ejectdock.rb file.
- Versioned release containing the application ZIP.

The cask must contain:

- An explicit version.
- A versioned download URL.
- The archive's SHA-256.
- Name and description.
- Project homepage.
- Minimum macOS version.
- A declaration of the application bundle to install.

Intended installation:

```sh
brew tap OWNER/tools
brew install --cask ejectdock
```

Upgrade:

```sh
brew upgrade --cask ejectdock
```

Uninstall:

```sh
brew uninstall --cask ejectdock
```

Preserve preferences during ordinary uninstallation. Remove them only through
an explicit cleanup operation.

Do not publish a cask with a fictitious URL or an unverified checksum.

If repositories or releases need to remain private, verify authentication for
archive downloads: Git access to the tap alone may not be sufficient.

## 9. Signing and architectures

Keep two separate workflows:

Personal development:

- Local compilation.
- Local signing.
- Installation on the development Mac.
- No paid developer account required for this workflow.

Downloaded distribution:

- Developer ID signing.
- Hardened Runtime according to Apple's requirements.
- Notarization.
- Staple the ticket to the bundle before archiving.
- Verify the final archive and test launching the application.

Homebrew does not bypass Gatekeeper requirements.

Without a distribution certificate, clearly document the limitations. Do not
include an automatic security bypass in the cask.

Start with the development Mac's architecture. For Intel and Apple Silicon
distribution, later choose between:

- A universal bundle.
- Two archives with architecture-specific URLs and checksums.

## 10. Release automation

After validating the local build:

- Run tests in macOS CI.
- Build a release from a version tag.
- Verify that the tag and bundle version match.
- Sign and notarize if credentials are configured.
- Produce the ZIP and its SHA-256.
- Publish the release.
- Update the cask with the exact version and checksum.

Limit workflow permissions. Do not expose certificates or secrets in logs.

Creating remote repositories, publishing, and configuring secrets are separate
steps from local development.

## 11. Validation

Focused automated tests:

- Persistent selection.
- Two disks with the same name.
- Ambiguous or changed identity.
- Grouping volumes by disk.
- Excluding internal and system disks.
- Disconnection during an operation.
- Partial failure.
- Repeated clicks.
- No connected targets.
- Recognizing and grouping disk images.

Manual tests:

- Left click, right click, and Option + click.
- An external disk with one volume.
- An external disk with multiple volumes, if available.
- Multiple disks with only one selected.
- Multiple mounted disk images.
- A busy disk and a backup in progress.
- Disconnecting and reconnecting.
- Restarting the application.
- Launch at login.
- Homebrew installation, upgrade, and uninstallation.
- Preference retention during an upgrade.

Start with temporary disk images and test media. Do not interrupt a real backup
for a test.

Document scenarios that could not be tested because hardware was unavailable.

## 12. Implementation order

Phase 1: foundation

- Initialize the project.
- Obtain a reproducible build.
- Display the icon and its menu.
- Validate mouse gestures.
- Display a read-only inventory.

Phase 2: primary functionality

- Identify disks.
- Persist the selection.
- Implement normal ejection.
- Add states and errors.
- Validate using test media.

Phase 3: additional functionality

- Eject all disk images.
- Eject all external disks.
- Add settings and launch at login.
- Verify accessibility.

Phase 4: local installation

- Assemble the bundle.
- Add build and installation scripts.
- Verify the installed application works.

Phase 5: distribution

- Prepare the tap and cask.
- Configure releases.
- Add signing and notarization according to available resources.
- Test a complete Homebrew installation.

## 13. Success criteria

- One click ejects only the configured targets.
- Right click and Option + click open the menu.
- The selection survives restarts and reconnections.
- A dedicated action can eject all disk images.
- No internal or system disk is targeted.
- A busy disk produces an explicit result without forced ejection.
- Partial success is distinguished from complete success.
- The application remains responsive during operations.
- Homebrew installation and upgrades are reproducible.
- Validation limitations are documented.

## 14. Working guidelines

Start by inspecting the project and environment, then implement incrementally.

Make routine technical decisions autonomously. Ask only for information that
truly blocks progress.

Do not eject the user's real backup drive without explicit permission for that
test.

Follow local instructions and Git conventions. Never use the em dash character.
Do not add co-author trailers or automatic generation notices to commits, code,
or documentation.

At each step, distinguish between:

- What is implemented.
- What is tested.
- What still needs verification.
- What depends on external access, certificates, or hardware.

## 15. Languages and settings

The source code, developer documentation, scripts, and project discussions in the
repository use English. The interface initially supports English and French.

Provide a language preference in the Settings menu:

- System Default: follow the macOS language preference, with English as fallback.
- English.
- Français.

Persist the choice across application restarts and apply changes immediately.
Keep interface strings in localization resources so that additional languages
can be contributed without rewriting interface logic. Preserve user-defined disk
names and mount paths exactly as reported by the system.
