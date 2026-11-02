import Foundation
import CryptoKit

public enum DiskTopologyError: Error { case malformedInventory }

/// Parses only structured system metadata. Unknown topology remains visible but disabled.
public enum DiskTopology {
    public static func targets(list: [String: Any], apfs: [String: Any],
                               info: [String: [String: Any]], images: [String: Any],
                               currentUserID: UInt32) throws -> [InventoryTarget] {
        guard let disks = list["AllDisksAndPartitions"] as? [[String: Any]],
              let containers = apfs["Containers"] as? [[String: Any]],
              let imageRecords = images["images"] as? [[String: Any]] else {
            throw DiskTopologyError.malformedInventory
        }
        var parent: [String: String] = [:]
        var nodes: [String: [String: Any]] = [:]
        var topologyNamesByRoot: [String: Set<String>] = [:]
        for disk in disks {
            guard let bsd = disk["DeviceIdentifier"] as? String, validBSD(bsd) else { continue }
            parent[bsd] = bsd
            nodes[bsd] = disk
            topologyNamesByRoot[bsd, default: []].insert(bsd)
            for partition in disk["Partitions"] as? [[String: Any]] ?? [] {
                guard let child = partition["DeviceIdentifier"] as? String else { continue }
                parent[child] = bsd
                nodes[child] = partition
                topologyNamesByRoot[bsd, default: []].insert(child)
            }
        }
        var volumesByDisk: [String: [[String: Any]]] = [:]
        var unsafeDisks = Set<String>()
        var apfsDisks = Set<String>()
        var resolvedStores = Set<String>()
        for container in containers {
            guard let reference = container["ContainerReference"] as? String else { continue }
            apfsDisks.insert(reference)
            let stores = container["PhysicalStores"] as? [[String: Any]] ?? []
            resolvedStores.formUnion(stores.compactMap { $0["DeviceIdentifier"] as? String })
            let roots = stores.compactMap { ($0["DeviceIdentifier"] as? String).flatMap { parent[$0] } }
            // Multi-store containers require an atomic multi-device contract, so all stores are blocked.
            if stores.count != 1 || roots.count != 1 {
                unsafeDisks.formUnion(roots)
                continue
            }
            let root = roots[0]
            topologyNamesByRoot[root, default: []].insert(reference)
            topologyNamesByRoot[root, default: []].formUnion(stores.compactMap { $0["DeviceIdentifier"] as? String })
            topologyNamesByRoot[root, default: []].formUnion(
                (container["Volumes"] as? [[String: Any]] ?? []).compactMap { $0["DeviceIdentifier"] as? String }
            )
            let listed = disks.first { $0["DeviceIdentifier"] as? String == reference }
            guard let listed, let volumes = listed["APFSVolumes"] as? [[String: Any]] else {
                unsafeDisks.insert(root)
                continue
            }
            volumesByDisk[root, default: []].append(contentsOf: volumes)
            for volume in container["Volumes"] as? [[String: Any]] ?? [] {
                if (volume["Roles"] as? [String] ?? []).contains("System") { unsafeDisks.insert(root) }
            }
        }
        for (name, node) in nodes {
            let content = node["Content"] as? String ?? ""
            if (content.hasPrefix("Apple_APFS") && content != "Apple_APFS_Container" && !resolvedStores.contains(name)) ||
                content.hasPrefix("Apple_RAID") || content == "Apple_CoreStorage" {
                if let root = parent[name] { unsafeDisks.insert(root) }
            }
        }
        // A container visible in list but missing from apfs is an incomplete snapshot.
        for disk in disks where disk["APFSPhysicalStores"] != nil {
            let bsd = disk["DeviceIdentifier"] as? String ?? ""
            if !apfsDisks.contains(bsd) {
                for store in disk["APFSPhysicalStores"] as? [[String: Any]] ?? [] {
                    if let child = store["DeviceIdentifier"] as? String, let root = parent[child] {
                        unsafeDisks.insert(root)
                    }
                }
            }
        }
        var imageByRoot: [String: [String: Any]] = [:]
        var allImageMembers = Set<String>()
        for record in imageRecords {
            let entities = record["system-entities"] as? [[String: Any]] ?? []
            let names = entities.compactMap { ($0["dev-entry"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } }
            allImageMembers.formUnion(names)
            let roots = names.filter { parent[$0] == $0 && !apfsDisks.contains($0) }
            if roots.count == 1 { imageByRoot[roots[0]] = record }
        }
        var result: [InventoryTarget] = []
        var identityTokensByBSD: [String: Set<String>] = [:]
        for disk in disks {
            guard let bsd = disk["DeviceIdentifier"] as? String, validBSD(bsd),
                  !apfsDisks.contains(bsd), disk["APFSPhysicalStores"] == nil else { continue }
            let metadata = info[bsd] ?? [:]
            let image = imageByRoot[bsd]
            let kind: InventoryTarget.Kind = image == nil ? .physical : .diskImage
            let children = disk["Partitions"] as? [[String: Any]] ?? []
            let volumeNodes = children + (volumesByDisk[bsd] ?? []) + [disk]
            let volumes = volumeNodes.compactMap { node -> ObservedVolume? in
                guard let name = node["DeviceIdentifier"] as? String,
                      node["VolumeName"] != nil || node["MountPoint"] != nil else { return nil }
                let mount = node["MountPoint"] as? String
                return ObservedVolume(bsdName: name, wholeBSDName: bsd,
                                      name: node["VolumeName"] as? String ?? name,
                                      mountPath: mount?.isEmpty == false ? mount : nil,
                                      isInternal: metadata["Internal"] as? Bool,
                                      volumeUUID: validUUID(node["VolumeUUID"]))
            }
            let tokens = Set(([disk] + children).compactMap { node in
                validUUID(node["DiskUUID"]) ?? validUUID(node["VolumeUUID"])
            })
            var witnesses: [String: String] = [:]
            for node in [disk] + children {
                if let name = node["DeviceIdentifier"] as? String,
                   let uuid = validUUID(node["DiskUUID"]) { witnesses[name] = uuid }
            }
            identityTokensByBSD[bsd] = tokens
            let size = (metadata["TotalSize"] as? NSNumber)?.uint64Value ?? (disk["Size"] as? NSNumber)?.uint64Value ?? 0
            let hardware = [metadata["BusProtocol"] as? String ?? "", metadata["MediaName"] as? String ?? ""]
            var identityParts = tokens.sorted() + [String(size)] + hardware
            if let image {
                // Identity is bound to the image file and UUIDs, never to a session BSD number.
                identityParts.append(image["image-path"] as? String ?? "")
            }
            let stableID = kind.rawValue + ":" + SHA256.hash(data: Data(identityParts.joined(separator: "\n").utf8))
                .map { String(format: "%02x", $0) }.joined()
            var rejection: String?
            if metadata["DeviceIdentifier"] as? String != bsd || metadata["WholeDisk"] as? Bool != true {
                rejection = "inventory.unknown"
            } else if metadata["Internal"] as? Bool != false {
                rejection = "inventory.internal"
            } else if metadata["OSInternalMedia"] as? Bool == true || metadata["SystemImage"] as? Bool == true ||
                        volumeNodes.contains(where: protectedVolume) {
                rejection = "inventory.system"
            } else if unsafeDisks.contains(bsd) || metadata["RAIDMaster"] as? Bool == true || metadata["RAIDSlice"] as? Bool == true {
                rejection = "inventory.topology"
            } else if let image {
                let path = image["image-path"] as? String ?? ""
                if path.isEmpty || (image["owner-uid"] as? NSNumber)?.uint32Value != currentUserID ||
                    path.hasPrefix("/System/") || path.contains("/.timemachine/") ||
                    volumes.contains(where: { $0.mountPath?.hasPrefix("/Library/Developer/") == true }) {
                    rejection = "inventory.system"
                } else if metadata["BusProtocol"] as? String != "Disk Image" { rejection = "inventory.unknown" }
            } else if allImageMembers.contains(bsd) || metadata["VirtualOrPhysical"] as? String != "Physical" {
                rejection = "inventory.unknown"
            }
            if rejection == nil && (tokens.isEmpty || witnesses.isEmpty || size == 0 ||
                volumes.contains(where: { $0.mountPath != nil && $0.volumeUUID == nil })) {
                rejection = "inventory.identity"
            }
            let dataName = (volumesByDisk[bsd] ?? []).compactMap { $0["VolumeName"] as? String }.first
                ?? children.filter { $0["Content"] as? String != "EFI" }.compactMap { $0["VolumeName"] as? String }.first
            let display = volumes.first(where: { $0.mountPath != nil })?.name ?? dataName ?? volumes.first?.name
                ?? metadata["MediaName"] as? String ?? bsd
            result.append(InventoryTarget(stableID: stableID, bsdName: bsd, name: display,
                                          kind: kind, volumes: volumes, selectable: rejection == nil,
                                          rejectionReason: rejection,
                                          isKnownInternal: metadata["Internal"] as? Bool == true,
                                          mediaUUIDs: witnesses,
                                          hasMountedSnapshots: volumeNodes.contains {
                                              !(($0["MountedSnapshots"] as? [[String: Any]]) ?? []).isEmpty
                                          }, topologyBSDNames: Array(topologyNamesByRoot[bsd] ?? [bsd]).sorted()))
        }
        // Any shared media UUID invalidates both targets, even when their hardware names differ.
        return result.map { target in
            let tokens = identityTokensByBSD[target.bsdName] ?? []
            let collision = result.contains { other in
                other.bsdName != target.bsdName &&
                (other.stableID == target.stableID || !tokens.isDisjoint(with: identityTokensByBSD[other.bsdName] ?? []))
            }
            guard collision else { return target }
            return InventoryTarget(stableID: target.stableID, bsdName: target.bsdName, name: target.name,
                                   kind: target.kind, volumes: target.volumes, selectable: false,
                                   rejectionReason: "inventory.ambiguous", isKnownInternal: target.isKnownInternal,
                                   mediaUUIDs: target.mediaUUIDs,
                                   hasMountedSnapshots: target.hasMountedSnapshots,
                                   topologyBSDNames: target.topologyBSDNames)
        }.sorted { $0.bsdName.localizedStandardCompare($1.bsdName) == .orderedAscending }
    }

    public static func validBSD(_ value: String) -> Bool {
        guard value.hasPrefix("disk") else { return false }
        let digits = value.dropFirst(4).utf8
        return !digits.isEmpty && digits.allSatisfy { (48...57).contains($0) }
    }

    private static func validUUID(_ value: Any?) -> String? {
        guard let string = value as? String, let uuid = UUID(uuidString: string) else { return nil }
        return uuid.uuidString
    }

    private static func protectedVolume(_ node: [String: Any]) -> Bool {
        if node["OSInternal"] as? Bool == true { return true }
        let mount = node["MountPoint"] as? String ?? ""
        if mount == "/" || mount.hasPrefix("/System/") { return true }
        return (node["MountedSnapshots"] as? [[String: Any]] ?? []).contains {
            let path = $0["SnapshotMountPoint"] as? String ?? ""
            return path == "/" || path.hasPrefix("/System/")
        }
    }
}
