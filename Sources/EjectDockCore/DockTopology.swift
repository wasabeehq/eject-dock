import CryptoKit
import Foundation

public enum DockTopology {
    public enum Readiness: Equatable {
        case ready
        case unavailable
        case blocked([String])
    }

    public static func targets(observed: [ObservedDock], inventory: [InventoryTarget]) -> [DockTarget] {
        let physicalByBSD = Dictionary(grouping: inventory.filter { $0.kind == .physical }, by: \.bsdName)
        var result = observed.map { dock -> DockTarget in
            let boundaries = Array(Set(dock.boundaryIDs)).sorted()
            let memberBSDNames = Array(Set(dock.memberBSDNames))
            let members = memberBSDNames.flatMap { physicalByBSD[$0] ?? [] }
            let memberIDs = Array(Set(members.map(\.stableID))).sorted()
            let serials = Array(Set(dock.serialNumbers.filter { !$0.isEmpty })).sorted()
            let persistence: DockPersistence = serials.count == 1 &&
                dock.serialNumbers.count == boundaries.count && !dock.vendorProductIDs.isEmpty
                ? .persistent : .sessionOnly
            let identityParts: [String]
            if persistence == .persistent {
                identityParts = serials + dock.vendorProductIDs.sorted()
            } else {
                identityParts = boundaries.map(String.init)
            }
            let stableID = "dock:" + persistence.rawValue + ":" + digest(identityParts)
            var rejection: String?
            if !dock.complete || boundaries.isEmpty || memberBSDNames.isEmpty || members.count != memberBSDNames.count {
                rejection = "inventory.topology"
            } else if memberIDs.count != members.count {
                rejection = "inventory.ambiguous"
            } else if members.contains(where: { !$0.selectable }) {
                rejection = members.first(where: { !$0.selectable })?.rejectionReason ?? "inventory.unknown"
            }
            return DockTarget(stableID: stableID, name: dock.name, persistence: persistence,
                              memberTargetIDs: memberIDs, boundaryIDs: boundaries,
                              selectable: rejection == nil, rejectionReason: rejection)
        }

        let membershipCounts = Dictionary(grouping: result.flatMap { dock in
            dock.memberTargetIDs.map { ($0, dock.stableID) }
        }, by: { $0.0 })
        let identityCounts = Dictionary(grouping: result, by: \.stableID)
        result = result.map { dock in
            let ambiguousMember = dock.memberTargetIDs.contains { (membershipCounts[$0]?.count ?? 0) > 1 }
            guard identityCounts[dock.stableID]?.count == 1, !ambiguousMember else {
                return DockTarget(stableID: dock.stableID, name: dock.name, persistence: dock.persistence,
                                  memberTargetIDs: dock.memberTargetIDs, boundaryIDs: dock.boundaryIDs,
                                  selectable: false, rejectionReason: "inventory.ambiguous")
            }
            return dock
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func members(of dock: DockTarget, in snapshot: InventorySnapshot) -> [InventoryTarget]? {
        let matches = snapshot.docks.filter { $0.stableID == dock.stableID }
        guard matches.count == 1, let current = matches.first, current.selectable,
              current.persistence == dock.persistence, current.boundaryIDs == dock.boundaryIDs,
              !current.memberTargetIDs.isEmpty else { return nil }
        let grouped = Dictionary(grouping: snapshot.targets, by: \.stableID)
        let members = current.memberTargetIDs.compactMap { id -> InventoryTarget? in
            guard let matches = grouped[id], matches.count == 1, let target = matches.first,
                  target.kind == .physical, target.selectable else { return nil }
            return target
        }
        guard members.count == current.memberTargetIDs.count else { return nil }
        return members.sorted { $0.stableID < $1.stableID }
    }

    public static func isReady(_ dock: DockTarget, in snapshot: InventorySnapshot) -> Bool {
        readiness(of: dock, in: snapshot) == .ready
    }

    public static func readiness(of dock: DockTarget, in snapshot: InventorySnapshot) -> Readiness {
        guard let members = members(of: dock, in: snapshot) else { return .unavailable }
        let memberIDs = Set(members.map(\.stableID))
        let blockers = snapshot.targets.filter { target in
            guard target.kind == .physical, !target.isKnownInternal else { return false }
            let mounted = target.hasMountedSnapshots || target.volumes.contains { $0.mountPath != nil }
            return mounted && (!memberIDs.contains(target.stableID) || !target.selectable)
        }.map(\.name).sorted()
        guard blockers.isEmpty else { return .blocked(blockers) }
        let dockBlockers = members.filter {
            $0.hasMountedSnapshots || $0.volumes.contains { $0.mountPath != nil }
        }.map(\.name).sorted()
        return dockBlockers.isEmpty ? .ready : .blocked(dockBlockers)
    }

    private static func digest(_ parts: [String]) -> String {
        SHA256.hash(data: Data(parts.joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}
