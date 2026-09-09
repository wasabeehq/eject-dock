import Foundation

public enum AppLanguage: String, CaseIterable {
    case system, english = "en", french = "fr"

    public func resolved(preferredLanguages: [String]) -> String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "fr"],
                                             forPreferences: preferredLanguages).first ?? "en"
    }
}

public final class LanguagePreferences {
    private let defaults: UserDefaults
    private let key = "applicationLanguage"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var language: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: key) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
