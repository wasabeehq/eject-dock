import Foundation

public struct USBDisplayDevice: Equatable {
    public let entryID: UInt64
    public let parentEntryID: UInt64?
    public let ancestorEntryIDs: [UInt64]
    public let containerID: String?
    public let manufacturer: String?
    public let product: String?
    public let vendorID: Int?
    public let productID: Int?
    public let isHub: Bool

    public init(entryID: UInt64, parentEntryID: UInt64?, ancestorEntryIDs: [UInt64] = [], containerID: String?,
                manufacturer: String?, product: String?, vendorID: Int? = nil,
                productID: Int? = nil, isHub: Bool) {
        self.entryID = entryID
        self.parentEntryID = parentEntryID
        self.ancestorEntryIDs = ancestorEntryIDs
        self.containerID = containerID
        self.manufacturer = manufacturer
        self.product = product
        self.vendorID = vendorID
        self.productID = productID
        self.isHub = isHub
    }
}

public struct DockHardwareDescriptor: Equatable {
    public let vendorID: Int
    public let productID: Int
    public let manufacturer: String?
    public let product: String?

    public init(vendorID: Int, productID: Int, manufacturer: String?, product: String?) {
        self.vendorID = vendorID
        self.productID = productID
        self.manufacturer = manufacturer
        self.product = product
    }
}

public enum DockDisplayName {
    public static func resolve(boundaryIDs: Set<UInt64>, fallbackNames: Set<String>,
                               devices: [USBDisplayDevice], hardware: [DockHardwareDescriptor]) -> String {
        let fallback = boundaryName(fallbackNames)
        guard !boundaryIDs.isEmpty else { return fallback }
        let boundaryContainers = Set(devices.compactMap { device -> String? in
            boundaryIDs.contains(device.entryID) ? comparisonKey(device.containerID) : nil
        })
        guard boundaryContainers.count == 1, let boundaryContainer = boundaryContainers.first else { return fallback }
        let companionRoots = Set(devices.compactMap { device -> UInt64? in
            guard device.isHub, !boundaryIDs.contains(device.entryID),
                  comparisonKey(device.containerID) == boundaryContainer else { return nil }
            return device.entryID
        })
        guard companionRoots.count <= 1 else { return fallback }
        let allowedRoots = boundaryIDs.union(companionRoots)
        let candidates = devices.compactMap { device -> (USBDisplayDevice, DockHardwareDescriptor)? in
            guard !device.isHub, let product = cleaned(device.product), isDockProduct(product) else {
                return nil
            }
            guard !allowedRoots.isDisjoint(with: device.ancestorEntryIDs),
                  let vendorID = device.vendorID, let productID = device.productID else { return nil }
            let matches = hardware.filter { $0.vendorID == vendorID && $0.productID == productID }
            return matches.count == 1 ? (device, matches[0]) : nil
        }
        guard candidates.count == 1 else { return fallback }
        return formattedName(candidates[0].0, hardware: candidates[0].1)
    }

    private static func formattedName(_ device: USBDisplayDevice, hardware: DockHardwareDescriptor) -> String {
        let product = cleaned(hardware.product) ?? cleaned(device.product)!
        guard let manufacturer = cleaned(device.manufacturer) ?? cleaned(hardware.manufacturer),
              manufacturer.caseInsensitiveCompare("Generic") != .orderedSame,
              product.range(of: manufacturer, options: [.caseInsensitive, .diacriticInsensitive]) == nil else {
            return product
        }
        return manufacturer + " " + product
    }

    private static func boundaryName(_ names: Set<String>) -> String {
        let normalizedNames = Set(names.compactMap(cleaned))
        let meaningful = normalizedNames.filter { !$0.localizedCaseInsensitiveContains("hub") }.sorted()
        return meaningful.first ?? normalizedNames.sorted().first ?? "USB Dock"
    }

    private static func isDockProduct(_ value: String) -> Bool {
        value.range(of: #"\bdocks?\b|\bdocking\s+station\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        return result.isEmpty ? nil : result
    }

    private static func comparisonKey(_ value: String?) -> String? {
        cleaned(value)?.lowercased()
    }

}
