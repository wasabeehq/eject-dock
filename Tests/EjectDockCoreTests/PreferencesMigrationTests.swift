import XCTest
@testable import EjectDockCore

final class PreferencesMigrationTests: XCTestCase {
    private func suite() -> (UserDefaults, String) {
        let name = "EjectDockMigrationTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    func testCopiesLegacyPreferencesIntoEmptyDomain() {
        let (legacy, legacyName) = suite()
        let (current, currentName) = suite()
        defer {
            legacy.removePersistentDomain(forName: legacyName)
            current.removePersistentDomain(forName: currentName)
        }
        legacy.set("fr", forKey: "applicationLanguage")
        legacy.set(true, forKey: "includeDiskImagesInPrimaryAction")

        XCTAssertTrue(PreferencesMigration.migrate(from: legacy, to: current))
        XCTAssertEqual(current.string(forKey: "applicationLanguage"), "fr")
        XCTAssertTrue(current.bool(forKey: "includeDiskImagesInPrimaryAction"))
    }

    func testNeverOverwritesExistingPreferences() {
        let (legacy, legacyName) = suite()
        let (current, currentName) = suite()
        defer {
            legacy.removePersistentDomain(forName: legacyName)
            current.removePersistentDomain(forName: currentName)
        }
        legacy.set("fr", forKey: "applicationLanguage")
        legacy.set(true, forKey: "includeDiskImagesInPrimaryAction")
        current.set("en", forKey: "applicationLanguage")

        XCTAssertFalse(PreferencesMigration.migrate(from: legacy, to: current))
        XCTAssertEqual(current.string(forKey: "applicationLanguage"), "en")
        XCTAssertNil(current.object(forKey: "includeDiskImagesInPrimaryAction"))
    }

    func testEmptyLegacyDomainCopiesNothing() {
        let (legacy, legacyName) = suite()
        let (current, currentName) = suite()
        defer {
            legacy.removePersistentDomain(forName: legacyName)
            current.removePersistentDomain(forName: currentName)
        }
        XCTAssertFalse(PreferencesMigration.migrate(from: legacy, to: current))
    }
}
