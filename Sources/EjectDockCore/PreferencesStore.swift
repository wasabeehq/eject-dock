import Foundation

public struct SavedTarget: Codable, Equatable {
    public let stableID: String
    public let name: String
    public let kind: InventoryTarget.Kind

    public init(stableID: String, name: String, kind: InventoryTarget.Kind) {
        self.stableID = stableID
        self.name = name
        self.kind = kind
    }

    public init(_ target: InventoryTarget) {
        self.init(stableID: target.stableID, name: target.name, kind: target.kind)
    }
}

public struct SavedDock: Codable, Equatable {
    public let stableID: String
    public let name: String

    public init(stableID: String, name: String) {
        self.stableID = stableID
        self.name = name
    }

    public init(_ dock: DockTarget) {
        self.init(stableID: dock.stableID, name: dock.name)
    }
}

public enum PrimaryActionMode: Equatable {
    case selectedDisks
    case dock(SavedDock)
}

public final class PreferencesStore {
    private enum Key {
        static let savedTargets = "savedEjectionTargets"
        static let includeDiskImages = "includeDiskImagesInPrimaryAction"
        static let primaryDock = "primaryDock"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var sessionDock: SavedDock?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var savedTargets: [SavedTarget] {
        guard let data = defaults.data(forKey: Key.savedTargets),
              let decoded = try? decoder.decode([SavedTarget].self, from: data) else {
            return []
        }
        var seen = Set<String>()
        return decoded.filter { !$0.stableID.isEmpty && seen.insert($0.stableID).inserted }
    }

    public var includeDiskImages: Bool {
        get { defaults.bool(forKey: Key.includeDiskImages) }
        set { defaults.set(newValue, forKey: Key.includeDiskImages) }
    }

    public var primaryActionMode: PrimaryActionMode {
        if let sessionDock { return .dock(sessionDock) }
        guard let data = defaults.data(forKey: Key.primaryDock),
              let dock = try? decoder.decode(SavedDock.self, from: data),
              !dock.stableID.isEmpty else { return .selectedDisks }
        return .dock(dock)
    }

    public func selectDock(_ dock: DockTarget) {
        let saved = SavedDock(dock)
        if dock.persistence == .persistent, let data = try? encoder.encode(saved) {
            sessionDock = nil
            defaults.set(data, forKey: Key.primaryDock)
        } else {
            defaults.removeObject(forKey: Key.primaryDock)
            sessionDock = saved
        }
    }

    public func useSelectedDisks() {
        sessionDock = nil
        defaults.removeObject(forKey: Key.primaryDock)
    }

    public func isSelected(_ stableID: String) -> Bool {
        savedTargets.contains { $0.stableID == stableID }
    }

    public func setSelected(_ target: InventoryTarget, selected: Bool) {
        setSelected(SavedTarget(target), selected: selected)
    }

    public func setSelected(_ target: SavedTarget, selected: Bool) {
        var targets = savedTargets.filter { $0.stableID != target.stableID }
        if selected {
            targets.append(target)
        }
        persist(targets)
    }

    public func refreshMetadata(from connectedTargets: [InventoryTarget]) {
        let connectedByID = Dictionary(grouping: connectedTargets, by: \.stableID)
        let refreshed = savedTargets.map { saved -> SavedTarget in
            guard let matches = connectedByID[saved.stableID], matches.count == 1,
                  let connected = matches.first, connected.selectable,
                  connected.kind == saved.kind else { return saved }
            return SavedTarget(connected)
        }
        persist(refreshed)
    }

    public func refreshMetadata(from snapshot: InventorySnapshot) {
        refreshMetadata(from: snapshot.targets)
        guard case .dock(let saved) = primaryActionMode else { return }
        let matches = snapshot.docks.filter { $0.stableID == saved.stableID }
        guard matches.count == 1, let current = matches.first, current.selectable else { return }
        if current.persistence == .sessionOnly {
            sessionDock = SavedDock(current)
        } else if let data = try? encoder.encode(SavedDock(current)) {
            defaults.set(data, forKey: Key.primaryDock)
        }
    }

    private func persist(_ targets: [SavedTarget]) {
        let sorted = targets.sorted {
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            return comparison == .orderedSame ? $0.stableID < $1.stableID : comparison == .orderedAscending
        }
        guard let data = try? encoder.encode(sorted) else { return }
        defaults.set(data, forKey: Key.savedTargets)
    }
}
