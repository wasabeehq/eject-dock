import Foundation

public enum UnmountVerification {
    /// Successful unmount keeps the physical target present. Disappearance,
    /// ambiguous identity, remounted volumes, and mounted snapshots are not success.
    public static func isConfirmed(_ requested: InventoryTarget, in inventory: [InventoryTarget]) -> Bool {
        let matches = inventory.filter { $0.stableID == requested.stableID }
        guard matches.count == 1, let current = matches.first,
              current.selectable, current.bsdName == requested.bsdName,
              current.kind == requested.kind, !current.hasMountedSnapshots else { return false }
        return current.volumes.allSatisfy { $0.mountPath == nil }
    }
}
