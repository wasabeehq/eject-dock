import XCTest
@testable import EjectDockCore

final class LanguagePreferencesTests: XCTestCase {
    func testLanguagePersistsAcrossStoreInstances() {
        let suite = "EjectDockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = LanguagePreferences(defaults: defaults)
        XCTAssertEqual(preferences.language, .system)
        preferences.language = .french
        XCTAssertEqual(LanguagePreferences(defaults: defaults).language, .french)
        preferences.language = .system
        XCTAssertEqual(LanguagePreferences(defaults: defaults).language, .system)
    }

    func testUnsupportedStoredValueUsesSystemDefault() {
        let suite = "EjectDockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unsupported", forKey: "applicationLanguage")
        XCTAssertEqual(LanguagePreferences(defaults: defaults).language, .system)
    }

    func testLanguageResolution() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-CA", "en-US"]), "fr")
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "fr"]), "en")
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["de-DE"]), "en")
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), "en")
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["fr"]), "en")
        XCTAssertEqual(AppLanguage.french.resolved(preferredLanguages: ["en"]), "fr")
    }
}
