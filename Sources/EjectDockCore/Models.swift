import Foundation

/// Session-only identifiers. These must never be persisted as disk identities.
public struct ObservedVolume: Equatable {
    public let bsdName: String
    public let wholeBSDName: String
    public let name: String
    public let mountPath: String?
    public let isInternal: Bool?
    public let volumeUUID: String?

    public init(bsdName: String, wholeBSDName: String, name: String,
                mountPath: String?, isInternal: Bool?, volumeUUID: String? = nil) {
        self.bsdName = bsdName
        self.wholeBSDName = wholeBSDName
        self.name = name
        self.mountPath = mountPath
        self.isInternal = isInternal
        self.volumeUUID = volumeUUID
    }
}

public struct ObservedDisk: Equatable {
    public let bsdName: String
    public let volumes: [ObservedVolume]
    public var isKnownInternal: Bool { volumes.contains { $0.isInternal == true } }
}

/// Persistent identity and the current session's native operation target.
public struct InventoryTarget: Equatable {
    public enum Kind: String, Codable { case physical, diskImage }
    public let stableID: String
    public let bsdName: String
    public let name: String
    public let kind: Kind
    public let volumes: [ObservedVolume]
    public let selectable: Bool
    public let rejectionReason: String?
    public let isKnownInternal: Bool
    public let mediaUUIDs: [String: String]
    public let hasMountedSnapshots: Bool
    public let topologyBSDNames: [String]

    public init(stableID: String, bsdName: String, name: String, kind: Kind,
                volumes: [ObservedVolume], selectable: Bool = true, rejectionReason: String? = nil,
                isKnownInternal: Bool = false, mediaUUIDs: [String: String] = [:], hasMountedSnapshots: Bool = false,
                topologyBSDNames: [String] = []) {
        self.stableID = stableID
        self.bsdName = bsdName
        self.name = name
        self.kind = kind
        self.volumes = volumes
        self.selectable = selectable
        self.rejectionReason = rejectionReason
        self.isKnownInternal = isKnownInternal
        self.mediaUUIDs = mediaUUIDs
        self.hasMountedSnapshots = hasMountedSnapshots
        self.topologyBSDNames = topologyBSDNames.isEmpty ? [bsdName] : topologyBSDNames
    }
}

public enum DockPersistence: String, Codable, Equatable {
    case persistent
    case sessionOnly
}

public struct ObservedDock: Equatable {
    public let boundaryIDs: [UInt64]
    public let containerID: String?
    public let serialNumbers: [String]
    public let name: String
    public let vendorProductIDs: [String]
    public let memberBSDNames: [String]
    public let complete: Bool

    public init(boundaryIDs: [UInt64], containerID: String?, serialNumbers: [String] = [], name: String,
                vendorProductIDs: [String], memberBSDNames: [String], complete: Bool) {
        self.boundaryIDs = boundaryIDs
        self.containerID = containerID
        self.serialNumbers = serialNumbers
        self.name = name
        self.vendorProductIDs = vendorProductIDs
        self.memberBSDNames = memberBSDNames
        self.complete = complete
    }
}

public struct DockTarget: Equatable {
    public let stableID: String
    public let name: String
    public let persistence: DockPersistence
    public let memberTargetIDs: [String]
    public let boundaryIDs: [UInt64]
    public let selectable: Bool
    public let rejectionReason: String?

    public init(stableID: String, name: String, persistence: DockPersistence,
                memberTargetIDs: [String], boundaryIDs: [UInt64], selectable: Bool = true,
                rejectionReason: String? = nil) {
        self.stableID = stableID
        self.name = name
        self.persistence = persistence
        self.memberTargetIDs = memberTargetIDs
        self.boundaryIDs = boundaryIDs
        self.selectable = selectable
        self.rejectionReason = rejectionReason
    }
}

public struct InventorySnapshot: Equatable {
    public let targets: [InventoryTarget]
    public let docks: [DockTarget]

    public init(targets: [InventoryTarget], docks: [DockTarget]) {
        self.targets = targets
        self.docks = docks
    }
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
