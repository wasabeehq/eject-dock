# Foundation validation

Checks performed on September 9, 2026.

## Completed

- Environment: Apple Silicon arm64 Mac, macOS 27.0, Swift 6.3.3.
- SDK selected by xcrun: macOS 26.5. Scripts explicitly set SDKROOT.
- `./scripts/test.sh`: 6 tests passed, no failures, including language preferences.
- `./scripts/archive.sh`: release build and bundle assembly succeeded.
- Ad hoc signature verified with `codesign --verify --deep --strict`.
- Info.plist validated with `plutil`.
- Local ZIP SHA-256 verification passed.
- Bundle launched with `open`: the running process was observed.

## Limitations

The desktop interface inspection tool timed out. Observing a running process
therefore does not validate menu rendering or actual interactions. Gesture tests
cover logical routing, not AppKit events.

The live inventory and its response to connection changes still need visual
verification. The grouping test covers the whole-disk names supplied as input;
it does not establish physical resolution of an APFS container.

## Manual verification checklist

- [ ] English and French menus, tooltip, accessibility label, and About panel.
- [ ] Language switching in the packaged application and across restarts.
- [ ] Visible menu bar icon and no permanent Dock icon.
- [ ] Left click, right click, Option + click, and Control + click.
- [ ] About panel and Quit action.
- [ ] Mount path appearances, disappearances, and changes.
- [ ] USB test media with one or multiple volumes, including APFS.
- [ ] Mounted disk images: identification and grouping in phase 3.
- [ ] Installation in Applications, application restart, and local update.
- [ ] Actual macOS 13 and Intel compatibility.

Ejection, persistence, and launch-at-login scenarios are not implemented yet.
No backup media has been ejected or unmounted. Homebrew, Developer ID signing,
and notarization still need to be prepared and validated.

## Language support checks

- English and French resource tables parse successfully, with 16 matching,
  nonempty keys in each language.
- All referenced interface keys exist in both languages.
- Tests cover preference persistence across store instances, unsupported stored
  values, regional language matching, and fallback to English.
- The build includes the translation resource bundle inside Contents/Resources.
- Full project documentation and script messages are in English. French text
  is confined to translations, native language names, and documented menu labels.
