import XCTest
@testable import EjectDockCore

final class DockDisplayNameTests: XCTestCase {
    private let container = "5CF3EE30-D507-4925-B001-802D79434C30"

    private func device(_ id: UInt64, parent: UInt64? = nil, container: String? = nil,
                        vendor: String? = nil, product: String? = nil, vendorID: Int? = nil,
                        productID: Int? = nil, hub: Bool = false,
                        ancestors: [UInt64] = []) -> USBDisplayDevice {
        USBDisplayDevice(entryID: id, parentEntryID: parent, ancestorEntryIDs: ancestors, containerID: container,
                         manufacturer: vendor, product: product, vendorID: vendorID,
                         productID: productID, isHub: hub)
    }

    private let hardware = [DockHardwareDescriptor(
        vendorID: 11145, productID: 1813, manufacturer: "Ugreen Group Limited",
        product: "Thunderbolt 5 Docking Station (13-in-1)"
    )]

    func testUsesSelfDescribedDockFunctionLinkedThroughUSBAncestorChain() {
        let devices = [
            device(1, parent: 10, container: container.lowercased(), product: "USB3.0 Hub", hub: true),
            device(2, parent: 10, container: container.lowercased(), product: "USB2.0 Hub", hub: true),
            device(3, parent: 2, vendor: "UGREEN", product: "Thunderbolt 5 Docking Station",
                   vendorID: 11145, productID: 1813, ancestors: [90, 2, 80]),
            device(4, parent: 2, vendor: "Camera Co", product: "Webcam", ancestors: [2])
        ]

        XCTAssertEqual(
            DockDisplayName.resolve(boundaryIDs: [1], fallbackNames: ["USB3.0 Hub"],
                                    devices: devices, hardware: hardware),
            "UGREEN Thunderbolt 5 Docking Station (13-in-1)"
        )
    }

    func testUnrelatedSiblingAndAmbiguousDockDescriptorsKeepFallback() {
        let unrelated = [
            device(1, parent: 20, container: container, product: "USB2.0 Hub", hub: true),
            device(30, parent: 40, container: container.lowercased(), product: "Other USB Hub", hub: true),
            device(31, parent: 50, container: container.lowercased(), product: "Third USB Hub", hub: true),
            device(2, parent: 30, vendor: "Camera Co", product: "Webcam", ancestors: [30])
        ]
        XCTAssertEqual(
            DockDisplayName.resolve(boundaryIDs: [1], fallbackNames: ["USB3.0 Hub"],
                                    devices: unrelated, hardware: hardware),
            "USB3.0 Hub"
        )

        let linkedBase = [
            device(1, parent: 20, container: container, product: "USB3.0 Hub", hub: true),
            device(30, parent: 40, container: container.lowercased(), product: "USB2.0 Hub", hub: true)
        ]
        let unlinkedDock = linkedBase + [
            device(5, parent: 99, vendor: "UGREEN", product: "Thunderbolt 5 Docking Station",
                   vendorID: 11145, productID: 1813, ancestors: [99])
        ]
        XCTAssertEqual(
            DockDisplayName.resolve(boundaryIDs: [1], fallbackNames: ["USB3.0 Hub"],
                                    devices: unlinkedDock, hardware: hardware),
            "USB3.0 Hub"
        )

        let ambiguous = linkedBase + [
            device(3, parent: 30, vendor: "UGREEN", product: "Thunderbolt 5 Docking Station",
                   vendorID: 11145, productID: 1813, ancestors: [30]),
            device(4, parent: 30, vendor: "UGREEN", product: "Thunderbolt 5 Docking Station",
                   vendorID: 11145, productID: 1813, ancestors: [30])
        ]
        XCTAssertEqual(
            DockDisplayName.resolve(boundaryIDs: [1], fallbackNames: ["USB3.0 Hub"],
                                    devices: ambiguous, hardware: hardware),
            "USB3.0 Hub"
        )
    }

    func testAvoidsRepeatingManufacturerAlreadyPresentInProduct() {
        let devices = [
            device(1, parent: 20, container: container, product: "USB2.0 Hub", hub: true),
            device(2, parent: 1, vendor: "Acme", product: "Acme Desk Dock", vendorID: 1, productID: 2,
                   ancestors: [1])
        ]
        let hardware = [DockHardwareDescriptor(
            vendorID: 1, productID: 2, manufacturer: "Acme Incorporated", product: "Acme Desk Dock"
        )]
        XCTAssertEqual(
            DockDisplayName.resolve(boundaryIDs: [1], fallbackNames: [], devices: devices, hardware: hardware),
            "Acme Desk Dock"
        )
    }
}
