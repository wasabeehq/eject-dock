import Foundation

/// Copies preferences saved under a previous bundle identifier into the current domain.
public enum PreferencesMigration {
    public static let legacyBundleIdentifiers = ["fr.leo.ejectdock"]

    public static let keys = [
        "savedEjectionTargets",
        "includeDiskImagesInPrimaryAction",
        "primaryDock",
        "applicationLanguage",
    ]

    /// Copies known keys from `legacy` only when `current` holds none of them,
    /// so preferences already written under the new identifier are never overwritten.
    @discardableResult
    public static func migrate(from legacy: UserDefaults, to current: UserDefaults,
                               keys: [String] = keys) -> Bool {
        guard !keys.contains(where: { current.object(forKey: $0) != nil }) else { return false }
        var copied = false
        for key in keys {
            guard let value = legacy.object(forKey: key) else { continue }
            current.set(value, forKey: key)
            copied = true
        }
        return copied
    }

    public static func migrateLegacyDomains(currentBundleIdentifier: String?,
                                            current: UserDefaults = .standard) {
        for identifier in legacyBundleIdentifiers where identifier != currentBundleIdentifier {
            guard let legacy = UserDefaults(suiteName: identifier) else { continue }
            if migrate(from: legacy, to: current) { return }
        }
    }
}
