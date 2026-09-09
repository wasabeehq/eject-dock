# Languages and settings

Project documentation, source comments, and command-line messages use English.
The application interface supports English and French.

Open **Settings > Language** to choose:

- **System Default**: use macOS preferred languages, falling back to English.
- **English**: always use English.
- **Français**: always use French.

The preference is stored in UserDefaults under `applicationLanguage`. Changing
the language updates the status item's tooltip and accessibility label immediately.
The next menu opening and About panel use the chosen language without restarting.
Disk names and mount paths are user data and are never translated.

## Translation resources

Strings live in `Sources/EjectDock/Resources/<language>.lproj/Localizable.strings`.
Use stable semantic keys, with the same keys in every language. Retrieve interface
text through `Localization.text(_:)`, including errors and accessibility labels.
Language names are intentionally shown in their native language to make switching
back possible even when the current interface language is unfamiliar.

Swift Package Manager processes these resources into a resource bundle. The build
script copies that bundle into EjectDock.app before signing, so installed copies
do not depend on the source tree. English is declared as the default localization
in Package.swift and Info.plist. The application identifier remains stable.

To add a language, add its resource directory, an AppLanguage case and menu label,
and update the supported languages in the language resolver and Info.plist.
Verify resource key parity, preference persistence, system-language fallback,
and menu rendering. Escape quotes and newlines using the `.strings` format.

## Settings scope

Language selection is the first implemented setting. Selected disks, launch at
login, and inclusion of disk images remain planned features. Keep these settings
in the menu until a dedicated window provides a clear usability benefit.
