# EjectDock icon assets

## Application icons

- `eject-dock-app-light.icns`: light macOS application icon.
- `eject-dock-app-dark.icns`: dark macOS application icon.
- `eject-dock-app-{light,dark}-1024.png`: transparent 1024 px PNG exports.
- `eject-dock-app-{light,dark}.iconset/`: standard macOS representations from 16 px to 1024 px, including Retina sizes.

The two application designs were isolated and cleaned from the supplied contact sheet. They are derived versions, not pixel-identical crops.

## Menu and document pictograms

`eject-dock-menu-document-{filled,outline}-{black,white}.svg` contains clean vector redraws of the supplied pictograms. Each has a transparent background. The filled drive has a transparent indicator hole; the outline drive has a filled indicator.

PNG exports are available at 16, 18, 22, 32, 36, 44, 64, 128, 256, 512 and 1024 px. Use paired sizes such as 18/36 or 22/44 for standard and Retina menu images. For AppKit menu use, mark the image as a template (`NSImage.isTemplate = true`) so the system supplies the appropriate appearance. The SVG sources are editable; PNG is the directly usable AppKit format.

## Sources

- `sources/eject-dock-original-icon-sheet.png`: unchanged user-supplied contact sheet.
- `sources/eject-dock-app-light-1254.png` and `sources/eject-dock-app-dark-1254.png`: high-resolution derived application masters.

These files are prepared for later integration. No application resource, build configuration or existing icon has been replaced.

## Validation

The application icon containers were built with `iconutil`. PNG dimensions, transparency and representative visual renders were checked. Integration and appearance in the running application remain to be checked when the icons are adopted.
