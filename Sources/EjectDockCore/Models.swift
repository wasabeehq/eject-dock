import Foundation

/// Session-only identifiers. These must never be persisted as disk identities.
public struct ObservedVolume: Equatable {
    public let bsdName: String
    public let wholeBSDName: String
    public let name: String
    public let mountPath: String?
    public let isInternal: Bool?

    public init(bsdName: String, wholeBSDName: String, name: String,
                mountPath: String?, isInternal: Bool?) {
        self.bsdName = bsdName
        self.wholeBSDName = wholeBSDName
        self.name = name
        self.mountPath = mountPath
        self.isInternal = isInternal
    }
}

public struct ObservedDisk: Equatable {
    public let bsdName: String
    public let volumes: [ObservedVolume]
    public var isKnownInternal: Bool { volumes.contains { $0.isInternal == true } }
}

public enum InventoryGrouping {
    /// Groups the topology reported by Disk Arbitration, not physical APFS stores.
    public static func group(_ volumes: [ObservedVolume]) -> [ObservedDisk] {
        Dictionary(grouping: volumes, by: \.wholeBSDName)
            .map { key, values in
                ObservedDisk(bsdName: key, volumes: values.sorted { $0.bsdName < $1.bsdName })
            }
            .sorted { $0.bsdName < $1.bsdName }
    }
}

public enum MenuGesture {
    public enum Action: Equatable { case openMenu, ejectSelection }
    public static func action(secondary: Bool, option: Bool, control: Bool,
                              hasSelection: Bool) -> Action {
        secondary || option || control || !hasSelection ? .openMenu : .ejectSelection
    }
}
