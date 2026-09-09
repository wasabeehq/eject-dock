import Foundation
import EjectDockCore

enum Localization {
    static let preferences = LanguagePreferences()
    private static let resources: Bundle = {
        // Packaged apps store resources in Contents/Resources; SwiftPM's
        // generated accessor otherwise looks beside the executable or build tree.
        if let url = Bundle.main.url(forResource: "EjectDock_EjectDock", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }()

    static func text(_ key: String) -> String {
        let language = preferences.language.resolved(preferredLanguages: Locale.preferredLanguages)
        let path = resources.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? resources
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
