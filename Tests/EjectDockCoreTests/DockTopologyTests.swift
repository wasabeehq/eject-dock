import XCTest
@testable import EjectDockCore

final class DockTopologyTests: XCTestCase {
    private func disk(_ id: String, bsd: String, mounted: Bool = true,
                      selectable: Bool = true, rejection: String? = nil,
                      knownInternal: Bool = false) -> InventoryTarget {
        InventoryTarget(
            stableID: id, bsdName: bsd, name: id, kind: .physical,
            volumes: [ObservedVolume(bsdName: bsd + "s1", wholeBSDName: bsd, name: id,
                                     mountPath: mounted ? "/Volumes/\(id)" : nil,
                                     isInternal: false, volumeUUID: UUID().uuidString)],
            selectable: selectable, rejectionReason: rejection, isKnownInternal: knownInternal
        )
    }

    private func observed(members: [String], serials: [String] = [], complete: Bool = true,
                          boundaries: [UInt64] = [42]) -> ObservedDock {
        ObservedDock(boundaryIDs: boundaries, containerID: UUID().uuidString,
                     serialNumbers: serials, name: "Desk Dock", vendorProductIDs: ["1234:5678"],
                     memberBSDNames: members, complete: complete)
    }

    func testSerialWitnessIsPersistentAndMissingSerialIsSessionOnly() throws {
        let target = disk("A", bsd: "disk8")
        let persistent = try XCTUnwrap(DockTopology.targets(
            observed: [observed(members: ["disk8"], serials: ["SERIAL-1"])], inventory: [target]
        ).first)
        let session = try XCTUnwrap(DockTopology.targets(
            observed: [observed(members: ["disk8"])], inventory: [target]
        ).first)
        XCTAssertEqual(persistent.persistence, .persistent)
        XCTAssertEqual(session.persistence, .sessionOnly)
        XCTAssertNotEqual(persistent.stableID, session.stableID)
        let partialSerial = try XCTUnwrap(DockTopology.targets(
            observed: [observed(members: ["disk8"], serials: ["SERIAL-1"], boundaries: [42, 43])],
            inventory: [target]
        ).first)
        XCTAssertEqual(partialSerial.persistence, .sessionOnly)
    }

    func testIncompleteUnknownAndDuplicateIdentityFailClosed() {
        let target = disk("A", bsd: "disk8")
        XCTAssertEqual(DockTopology.targets(
            observed: [observed(members: ["disk8"], complete: false)], inventory: [target]
        ).first?.rejectionReason, "inventory.topology")
        XCTAssertEqual(DockTopology.targets(
            observed: [observed(members: ["disk9"])], inventory: [target]
        ).first?.rejectionReason, "inventory.topology")
        let clones = DockTopology.targets(
            observed: [
                observed(members: ["disk8"], serials: ["S"], boundaries: [1]),
                observed(members: ["disk8"], serials: ["S"], boundaries: [2])
            ], inventory: [target]
        )
        XCTAssertTrue(clones.allSatisfy { !$0.selectable && $0.rejectionReason == "inventory.ambiguous" })
    }

    func testRejectedDockMemberAndOtherMountedExternalTargetBlockReadiness() throws {
        let member = disk("A", bsd: "disk8", mounted: false)
        let rejected = disk("B", bsd: "disk9", selectable: false, rejection: "inventory.identity")
        XCTAssertFalse(DockTopology.targets(
            observed: [observed(members: ["disk8", "disk9"])], inventory: [member, rejected]
        )[0].selectable)

        let dock = try XCTUnwrap(DockTopology.targets(
            observed: [observed(members: ["disk8"])], inventory: [member, rejected]
        ).first)
        let snapshot = InventorySnapshot(targets: [member, rejected], docks: [dock])
        XCTAssertEqual(DockTopology.readiness(of: dock, in: snapshot), .blocked(["B"]))
    }

    func testReadyRequiresConnectedNonemptyDockAndEveryMemberUnmounted() throws {
        let member = disk("A", bsd: "disk8", mounted: false)
        let dock = try XCTUnwrap(DockTopology.targets(
            observed: [observed(members: ["disk8"])], inventory: [member]
        ).first)
        XCTAssertEqual(DockTopology.readiness(
            of: dock, in: InventorySnapshot(targets: [member], docks: [dock])
        ), .ready)
        XCTAssertEqual(DockTopology.readiness(
            of: dock, in: InventorySnapshot(targets: [member], docks: [])
        ), .unavailable)
    }

    func testOnlyPositivelyKnownInternalMountedMediaIsIgnored() throws {
        let member = disk("A", bsd: "disk8", mounted: false)
        let dock = try XCTUnwrap(DockTopology.targets(
            observed: [observed(members: ["disk8"])], inventory: [member]
        ).first)
        let externalSystem = disk("External System", bsd: "disk9", rejection: "inventory.system")
        let unknownInternal = disk("Unknown", bsd: "disk10", rejection: "inventory.internal")
        let knownInternal = disk("Macintosh HD", bsd: "disk0", rejection: "inventory.internal", knownInternal: true)

        XCTAssertEqual(DockTopology.readiness(
            of: dock, in: InventorySnapshot(targets: [member, externalSystem], docks: [dock])
        ), .blocked(["External System"]))
        XCTAssertEqual(DockTopology.readiness(
            of: dock, in: InventorySnapshot(targets: [member, unknownInternal], docks: [dock])
        ), .blocked(["Unknown"]))
        XCTAssertEqual(DockTopology.readiness(
            of: dock, in: InventorySnapshot(targets: [member, knownInternal], docks: [dock])
        ), .ready)
    }
}
