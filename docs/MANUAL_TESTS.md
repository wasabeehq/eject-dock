# Manual acceptance checklist

Physical disk actions now unmount volumes only. The device remaining visible
in Disk Utility is expected. Disk image actions still detach the image.

Use the installed application in `~/Applications/EjectDock.app`. Record results
by number. Automated test results are recorded separately in `VALIDATION.md`.
Use disposable images and test media first. A real backup drive must not be
unmounted during an active backup for this checklist.

## Application and settings

- [ ] **1. Launch:** one menu bar icon appears, without a permanent Dock icon.
- [ ] **2. Panel:** left click and Option + click open the graphical panel.
      With no saved selection and the image option disabled, right click and
      Control + click open it too.
      Click outside to dismiss. Reopen and expand Settings within the panel.
- [ ] **3. Languages:** switch to French, English, then System Default. Menus,
      tooltip, About, and result labels use the expected language.
- [ ] **4. Persistence:** choose French, quit, and reopen. The language is retained.
- [ ] **5. Inventory:** attach a test disk or image. Its volumes and mount paths
      appear. Internal and protected media expose no enabled ejection action.

## Ejection and selection

- [ ] **6. Single target:** use Eject Now on a disposable image. The application
      reports completion and the image disappears from Finder and the inventory.
- [ ] **7. Saved selection:** select one external test disk. Right click (or Control + click) unmounts
      only that disk's volumes. Another connected unselected disk remains mounted.
      Changing a disk toggle alone must not unmount anything. Reopen the panel
      and verify the toggle retains its value.
- [ ] **7a. Dock target:** choose a USB dock with a proven complete subtree as
      the right-click action.
      Connect another eligible test disk through that dock after making the
      choice. Right click must include both current dock disks and must leave an
      unrelated external disk mounted. The panel must explain that this remaining
      storage blocks dock-ready confirmation, without trying to unmount it.
- [ ] **7c. Unsupported boundary:** connect native Thunderbolt or PCIe storage
      whose dock boundary cannot be proven. It must remain absent from the dock
      target choices while retaining its safe individual-disk action.
- [ ] **7b. Dock confirmation:** after every current dock volume is confirmed
      unmounted and no mounted external storage remains outside the proven dock
      boundary, a nonactivating toast appears below the menu bar icon on the same
      screen for about four seconds. It has no buttons and creates no Notification
      Center entry. A busy, missing, incomplete, ambiguous, empty, timed-out, or
      externally blocked dock never shows the success message. Failure details
      remain available in the panel.
- [ ] **8. Reconnection:** reconnect the selected disk and restart the application.
      Its selection is retained even if its BSD number changes.
- [ ] **9. Disconnected selection:** unplug a selected test disk after ejection.
      Its saved selection remains visible and removable. Right click with no
      selected disk connected reports that state without targeting another disk.
- [ ] **10. Multiple volumes:** a test APFS disk with several volumes appears as
      one physical target. Unmounting removes all its mount paths while the physical device remains present.
- [ ] **11. Busy disk and partial result:** keep a file open on disposable media
      using a process that prevents normal unmount. Request ejection together
      with another test disk. Results are explicit for each disk; no force or
      process termination occurs. Close the file and retry the failed target.
- [ ] **12. Repeated click and disconnection:** click repeatedly during an
      operation. No duplicate request starts. If a test disk disappears during
      the operation, the application stays responsive and reports its result.
- [ ] **13. Image actions:** mount two disposable images. Eject All Disk Images
      removes both eligible images. Protected system images remain excluded.
      Verify the image option is initially off and, when enabled, includes
      eligible images in the right-click action.
- [ ] **14. All external disks:** with test media only, verify the action unmounts
      eligible physical external disks and leaves internal media untouched.

## Installation and accessibility

- [ ] **15. Launch at login:** enable it in Settings, grant macOS approval if
      requested, then sign out and back in. Verify startup, then disable it and
      confirm the system setting reflects the change.
- [ ] **16. Local update:** quit, run `./scripts/install.sh`, and reopen. Language,
      saved selections, and the image preference are retained.
- [ ] **17. Accessibility:** inspect with VoiceOver and increased contrast.
      Progress, failure, partial completion, and success remain understandable
      without relying on icon color or notification permission.
      Check keyboard navigation, light and dark appearances, long disk names,
      scrolling with many disks, dock selection, both toast styles, and expanded
      settings in both languages and on each connected screen.

## Separate distribution gates

- [ ] Launch and test on macOS 13.
- [ ] Launch and test on an Intel Mac.
- [ ] Sign, notarize, staple, and verify using a valid Developer ID certificate.
- [ ] Download the final release on another Mac and verify normal launching.
- [ ] Validate Homebrew install, upgrade, uninstall, preference retention, and
      explicit preference cleanup using the published tap and release.

A multi-store APFS container is deliberately disabled. Supporting it requires
an explicit operation contract covering every backing physical device.
