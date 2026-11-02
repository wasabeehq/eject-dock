import DiskArbitration
import EjectDockCore
import Foundation
import IOKit

enum IORegistryDockDiscovery {
    private struct Boundary {
        let entryID: UInt64
        let containerID: String?
        let serialNumber: String?
        let name: String
        let vendorProductID: String
    }

    private struct Group {
        var boundaryIDs = Set<UInt64>()
        var containerID: String?
        var serialByBoundary: [UInt64: String] = [:]
        var names = Set<String>()
        var vendorProductIDs = Set<String>()
        var memberBSDNames = Set<String>()
        var complete = false
    }

    static func docks(for targets: [InventoryTarget]) -> [ObservedDock] {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return [] }
        let displayDevices = usbDisplayDevices()
        let dockHardware = dockHardwareDescriptors()
        let physical = targets.filter { $0.kind == .physical }
        let rootByTopologyName = physical.reduce(into: [String: String]()) { result, target in
            for name in target.topologyBSDNames { result[name] = target.bsdName }
        }
        var groups: [String: Group] = [:]
        for target in physical {
            guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, "/dev/" + target.bsdName) else {
                continue
            }
            let media = DADiskCopyIOMedia(disk)
            guard media != 0 else { continue }
            defer { IOObjectRelease(media) }
            guard let boundary = topLevelUSBOnlyHub(from: media) else { continue }
            let key = boundary.containerID.map { "container:" + $0.lowercased() }
                ?? "entry:\(boundary.entryID)"
            var group = groups[key] ?? Group(containerID: boundary.containerID)
            group.boundaryIDs.insert(boundary.entryID)
            if let serial = boundary.serialNumber { group.serialByBoundary[boundary.entryID] = serial }
            group.names.insert(boundary.name)
            group.vendorProductIDs.insert(boundary.vendorProductID)
            group.memberBSDNames.insert(target.bsdName)
            groups[key] = group
        }

        for key in groups.keys {
            var group = groups[key]!
            var coverageComplete = true
            for boundaryID in group.boundaryIDs {
                guard let names = descendantMediaNames(of: boundaryID) else {
                    coverageComplete = false
                    continue
                }
                for name in names {
                    guard let root = rootByTopologyName[name] else {
                        coverageComplete = false
                        continue
                    }
                    group.memberBSDNames.insert(root)
                }
            }
            group.complete = coverageComplete
            groups[key] = group
        }

        return groups.values.map { group in
            let resolvedName = DockDisplayName.resolve(
                boundaryIDs: group.boundaryIDs, fallbackNames: group.names,
                devices: displayDevices, hardware: dockHardware
            )
            return ObservedDock(
                boundaryIDs: group.boundaryIDs.sorted(), containerID: group.containerID,
                serialNumbers: group.boundaryIDs.compactMap { group.serialByBoundary[$0] }.sorted(),
                name: resolvedName,
                vendorProductIDs: group.vendorProductIDs.sorted(),
                memberBSDNames: group.memberBSDNames.sorted(), complete: group.complete
            )
        }
    }

    private static func topLevelUSBOnlyHub(from media: io_registry_entry_t) -> Boundary? {
        var current = media
        var ownsCurrent = false
        var candidate: Boundary?
        var hasThunderboltAncestor = false
        defer { if ownsCurrent { IOObjectRelease(current) } }
        while true {
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else { break }
            if ownsCurrent { IOObjectRelease(current) }
            current = parent
            ownsCurrent = true
            if IOObjectConformsTo(current, "IOThunderboltSwitch") != 0 ||
                IOObjectConformsTo(current, "IOThunderboltNub") != 0 {
                hasThunderboltAncestor = true
            }
            guard IOObjectConformsTo(current, "IOUSBHostDevice") != 0 else { continue }
            let values = properties(of: current)
            guard number(values["bDeviceClass"]) == 9,
                  values["Built-In"] as? Bool != true,
                  let entryID = registryEntryID(current),
                  let vendor = number(values["idVendor"]),
                  let product = number(values["idProduct"]) else { continue }
            let containerID = string(values["kUSBContainerID"]).flatMap { UUID(uuidString: $0)?.uuidString }
            let serial = string(values["USB Serial Number"]) ?? string(values["kUSBSerialNumberString"])
            let name = string(values["USB Product Name"])
                ?? string(values["kUSBProductString"]) ?? "USB Dock"
            candidate = Boundary(entryID: entryID, containerID: containerID, serialNumber: serial,
                                 name: name, vendorProductID: String(format: "%04x:%04x", vendor, product))
        }
        return hasThunderboltAncestor ? nil : candidate
    }

    private static func descendantMediaNames(of boundaryID: UInt64) -> Set<String>? {
        guard let matching = IORegistryEntryIDMatching(boundaryID) else { return nil }
        let boundary = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard boundary != 0 else { return nil }
        defer { IOObjectRelease(boundary) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(
            boundary, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var names = Set<String>()
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }
            guard IOObjectConformsTo(entry, "IOMedia") != 0 else { continue }
            if let name = string(properties(of: entry)["BSD Name"]), name.hasPrefix("disk") {
                names.insert(name)
            }
        }
        return names
    }

    private static func properties(of entry: io_registry_entry_t) -> [String: Any] {
        var raw: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &raw, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = raw?.takeRetainedValue() else { return [:] }
        return dictionary as NSDictionary as? [String: Any] ?? [:]
    }

    private static func registryEntryID(_ entry: io_registry_entry_t) -> UInt64? {
        var value: UInt64 = 0
        return IORegistryEntryGetRegistryEntryID(entry, &value) == KERN_SUCCESS ? value : nil
    }

    private static func usbDisplayDevices() -> [USBDisplayDevice] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator
        ) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var devices: [USBDisplayDevice] = []
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }
            guard let entryID = registryEntryID(entry) else { continue }
            let values = properties(of: entry)
            var parent: io_registry_entry_t = 0
            let parentID: UInt64?
            if IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) == KERN_SUCCESS {
                parentID = registryEntryID(parent)
                IOObjectRelease(parent)
            } else {
                parentID = nil
            }
            devices.append(USBDisplayDevice(
                entryID: entryID,
                parentEntryID: parentID,
                ancestorEntryIDs: ancestorEntryIDs(of: entry),
                containerID: string(values["kUSBContainerID"]),
                manufacturer: string(values["USB Vendor Name"]) ?? string(values["kUSBVendorString"]),
                product: string(values["USB Product Name"]) ?? string(values["kUSBProductString"]),
                vendorID: number(values["idVendor"]),
                productID: number(values["idProduct"]),
                isHub: number(values["bDeviceClass"]) == 9
            ))
        }
        return devices
    }

    private static func ancestorEntryIDs(of entry: io_registry_entry_t) -> [UInt64] {
        var ids: [UInt64] = []
        var current = entry
        var ownsCurrent = false
        defer { if ownsCurrent { IOObjectRelease(current) } }
        while true {
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else { break }
            if ownsCurrent { IOObjectRelease(current) }
            current = parent
            ownsCurrent = true
            if let entryID = registryEntryID(current) { ids.append(entryID) }
        }
        return ids
    }

    private static func dockHardwareDescriptors() -> [DockHardwareDescriptor] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOThunderboltSwitch"), &iterator
        ) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var descriptors: [DockHardwareDescriptor] = []
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }
            let values = properties(of: entry)
            guard let vendorID = number(values["Device Vendor ID"]),
                  let productID = number(values["Device Model ID"]) else { continue }
            descriptors.append(DockHardwareDescriptor(
                vendorID: vendorID,
                productID: productID,
                manufacturer: string(values["Device Vendor Name"]),
                product: string(values["Device Model Name"])
            ))
        }
        return descriptors
    }

    private static func number(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}
