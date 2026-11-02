import XCTest
@testable import EjectDockCore

final class PreferencesStoreTests: XCTestCase {
    private func defaults() -> (UserDefaults, String) {
        let suite = "EjectDockPreferencesTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    func testSelectionPersistsAndCanBeRemovedWhileDisconnected() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let target = InventoryTarget(
            stableID: "hardware:123", bsdName: "disk4", name: "Backup",
            kind: .physical, volumes: []
        )

        PreferencesStore(defaults: defaults).setSelected(target, selected: true)

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.savedTargets, [SavedTarget(target)])
        reloaded.setSelected(reloaded.savedTargets[0], selected: false)
        XCTAssertTrue(PreferencesStore(defaults: defaults).savedTargets.isEmpty)
    }

    func testSelectionUsesStableIdentityAndRefreshesDisplayMetadata() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let original = InventoryTarget(
            stableID: "volume:AAA", bsdName: "disk4", name: "Old name",
            kind: .physical, volumes: []
        )
        let reconnected = InventoryTarget(
            stableID: "volume:AAA", bsdName: "disk9", name: "New name",
            kind: .physical, volumes: []
        )

        store.setSelected(original, selected: true)
        store.setSelected(reconnected, selected: true)
        XCTAssertEqual(store.savedTargets, [SavedTarget(reconnected)])

        store.setSelected(original, selected: true)
        store.refreshMetadata(from: [reconnected])
        XCTAssertEqual(store.savedTargets, [SavedTarget(reconnected)])
    }

    func testAmbiguousOrRejectedInventoryPreservesSavedMetadata() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let saved = SavedTarget(stableID: "physical:AAA", name: "Original", kind: .physical)
        store.setSelected(saved, selected: true)
        let first = InventoryTarget(stableID: saved.stableID, bsdName: "disk4", name: "Clone A", kind: .physical, volumes: [])
        let second = InventoryTarget(stableID: saved.stableID, bsdName: "disk9", name: "Clone B", kind: .physical, volumes: [])
        store.refreshMetadata(from: [first, second])
        XCTAssertEqual(store.savedTargets, [saved])
        let rejected = InventoryTarget(stableID: saved.stableID, bsdName: "disk4", name: "Unsafe", kind: .physical,
                                       volumes: [], selectable: false, rejectionReason: "inventory.ambiguous")
        store.refreshMetadata(from: [rejected])
        XCTAssertEqual(store.savedTargets, [saved])
        store.refreshMetadata(from: [])
        XCTAssertEqual(store.savedTargets, [saved])
        let differentKind = InventoryTarget(stableID: saved.stableID, bsdName: "disk4", name: "Image", kind: .diskImage, volumes: [])
        store.refreshMetadata(from: [differentKind])
        XCTAssertEqual(store.savedTargets, [saved])
        store.refreshMetadata(from: [first])
        XCTAssertEqual(store.savedTargets, [SavedTarget(first)])
    }

    func testDiskImagesAreExcludedFromPrimaryActionByDefault() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)

        XCTAssertFalse(store.includeDiskImages)
        store.includeDiskImages = true
        XCTAssertTrue(PreferencesStore(defaults: defaults).includeDiskImages)
    }

    func testCorruptAndDuplicateStoredSelectionsFailClosed() throws {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "savedEjectionTargets")
        XCTAssertTrue(PreferencesStore(defaults: defaults).savedTargets.isEmpty)

        let duplicate = SavedTarget(stableID: "same", name: "Backup", kind: .physical)
        defaults.set(try JSONEncoder().encode([duplicate, duplicate]), forKey: "savedEjectionTargets")
        XCTAssertEqual(PreferencesStore(defaults: defaults).savedTargets, [duplicate])
    }

    func testAmbiguousConnectedIdentityDoesNotReplaceSavedMetadataOrTrap() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let saved = SavedTarget(stableID: "duplicate", name: "Known disk", kind: .physical)
        store.setSelected(saved, selected: true)
        let first = InventoryTarget(stableID: "duplicate", bsdName: "disk4", name: "First",
                                    kind: .physical, volumes: [], selectable: false)
        let second = InventoryTarget(stableID: "duplicate", bsdName: "disk5", name: "Second",
                                     kind: .physical, volumes: [], selectable: false)

        store.refreshMetadata(from: [first, second])

        XCTAssertEqual(store.savedTargets, [saved])
    }

    func testDockModePreservesSelectedDisksAndPersistentDockAcrossRestart() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let disk = InventoryTarget(stableID: "disk:A", bsdName: "disk8", name: "Backup",
                                   kind: .physical, volumes: [])
        let dock = DockTarget(stableID: "dock:A", name: "Desk Dock", persistence: .persistent,
                              memberTargetIDs: [disk.stableID], boundaryIDs: [1])
        store.setSelected(disk, selected: true)
        store.selectDock(dock)

        XCTAssertEqual(store.primaryActionMode, .dock(SavedDock(dock)))
        XCTAssertEqual(store.savedTargets, [SavedTarget(disk)])
        XCTAssertEqual(PreferencesStore(defaults: defaults).primaryActionMode, .dock(SavedDock(dock)))

        store.useSelectedDisks()
        XCTAssertEqual(store.primaryActionMode, .selectedDisks)
        XCTAssertEqual(store.savedTargets, [SavedTarget(disk)])
    }

    func testSessionOnlyDockIsNeverPersisted() {
        let (defaults, suite) = defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let dock = DockTarget(stableID: "dock:session:1", name: "USB Dock", persistence: .sessionOnly,
                              memberTargetIDs: ["A"], boundaryIDs: [1])
        store.selectDock(dock)
        XCTAssertEqual(store.primaryActionMode, .dock(SavedDock(dock)))
        XCTAssertEqual(PreferencesStore(defaults: defaults).primaryActionMode, .selectedDisks)
    }
}
