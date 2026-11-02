import XCTest
@testable import EjectDockCore

final class DiskTopologyTests: XCTestCase {
    func testMountedBackupSnapshotsRemainVisibleToUnmountVerification() throws {
        var value = disk()
        var partitions = value["Partitions"] as! [[String: Any]]
        partitions[0]["MountedSnapshots"] = [["SnapshotMountPoint": "/Volumes/BackupSnapshot"]]
        value["Partitions"] = partitions
        let target = try parse([value], info: ["disk4": metadata()])[0]
        XCTAssertTrue(target.hasMountedSnapshots)
        XCTAssertFalse(UnmountVerification.isConfirmed(target, in: [target]))
    }

    func testUnmountedDataNameDoesNotBecomeEFI() throws {
        var value = disk()
        value["Partitions"] = [
            ["DeviceIdentifier": "disk4s1", "Content": "EFI", "VolumeName": "EFI", "DiskUUID": uuidA],
            ["DeviceIdentifier": "disk4s2", "Content": "Apple_HFS", "VolumeName": "Data", "DiskUUID": uuidB]
        ]
        let target = try parse([value], info: ["disk4": metadata()])[0]
        XCTAssertEqual(target.name, "Data")
    }
    private let uuidA = "10000000-0000-0000-0000-000000000001"
    private let uuidB = "20000000-0000-0000-0000-000000000002"
    private func disk(_ bsd: String = "disk4", uuid: String? = nil) -> [String: Any] {
        ["DeviceIdentifier": bsd, "Size": 10000, "Partitions": [
            ["DeviceIdentifier": bsd + "s1", "DiskUUID": uuid ?? uuidA, "VolumeUUID": uuidB, "VolumeName": "Portable", "MountPoint": "/Volumes/Portable"]
        ]]
    }
    private func metadata(_ bsd: String = "disk4") -> [String: Any] {
        ["DeviceIdentifier": bsd, "WholeDisk": true, "Internal": false,
         "VirtualOrPhysical": "Physical", "BusProtocol": "USB", "MediaName": "Test Drive", "TotalSize": 10000]
    }
    private func parse(_ disks: [[String: Any]], info: [String: [String: Any]],
                       containers: [[String: Any]] = [], images: [[String: Any]] = []) throws -> [InventoryTarget] {
        try DiskTopology.targets(list: ["AllDisksAndPartitions": disks], apfs: ["Containers": containers],
                                 info: info, images: ["images": images], currentUserID: 501)
    }
    func testIdentitySurvivesBSDAndNameChange() throws {
        let first = try parse([disk()], info: ["disk4": metadata()])[0]
        var secondDisk = disk("disk9")
        var partition = (secondDisk["Partitions"] as! [[String: Any]])[0]
        partition["VolumeName"] = "Renamed"
        secondDisk["Partitions"] = [partition]
        let second = try parse([secondDisk], info: ["disk9": metadata("disk9")])[0]
        XCTAssertTrue(first.selectable)
        XCTAssertEqual(first.stableID, second.stableID)
        XCTAssertEqual(second.mediaUUIDs, ["disk9s1": uuidA])
        XCTAssertEqual(second.volumes.first?.volumeUUID, uuidB)
    }
    func testInternalUnknownAndVirtualDevicesAreBlocked() throws {
        for mutation in [["Internal": true], ["Internal": "unknown"], ["VirtualOrPhysical": "Virtual"]] as [[String: Any]] {
            var info = metadata()
            info.merge(mutation) { _, value in value }
            XCTAssertFalse(try parse([disk()], info: ["disk4": info])[0].selectable)
        }
        XCTAssertFalse(try parse([disk()], info: [:])[0].selectable)
    }
    func testCloneUUIDCollisionBlocksBothDespiteDifferentHardware() throws {
        var secondInfo = metadata("disk9")
        secondInfo["MediaName"] = "Different enclosure"
        let targets = try parse([disk(), disk("disk9")], info: ["disk4": metadata(), "disk9": secondInfo])
        XCTAssertEqual(targets.count, 2)
        XCTAssertTrue(targets.allSatisfy { !$0.selectable && $0.rejectionReason == "inventory.ambiguous" })
    }
    func testSameDisplayNameWithDistinctUUIDsRemainsSelectable() throws {
        let targets = try parse([disk(), disk("disk9", uuid: uuidB)], info: ["disk4": metadata(), "disk9": metadata("disk9")])
        XCTAssertTrue(targets.allSatisfy(\.selectable))
        XCTAssertNotEqual(targets[0].stableID, targets[1].stableID)
    }
    func testMountedVolumeWithoutVolumeWitnessIsRejected() throws {
        var value = disk()
        value["Partitions"] = [["DeviceIdentifier": "disk4s1", "DiskUUID": uuidA, "MountPoint": "/Volumes/Test"]]
        XCTAssertEqual(try parse([value], info: ["disk4": metadata()])[0].rejectionReason, "inventory.identity")
    }
    func testMissingIdentityBlocked() throws {
        var value = disk()
        value["Partitions"] = [["DeviceIdentifier": "disk4s1", "VolumeName": "Portable"]]
        XCTAssertEqual(try parse([value], info: ["disk4": metadata()])[0].rejectionReason, "inventory.identity")
    }
    func testAPFSVolumesFollowPhysicalStoreAndSystemRoleBlocks() throws {
        let logical: [String: Any] = ["DeviceIdentifier": "disk7", "APFSPhysicalStores": [["DeviceIdentifier": "disk4s1"]],
                                     "APFSVolumes": [["DeviceIdentifier": "disk7s1", "VolumeUUID": uuidB, "VolumeName": "Data", "MountPoint": "/Volumes/Data"]]]
        var container: [String: Any] = ["ContainerReference": "disk7", "PhysicalStores": [["DeviceIdentifier": "disk4s1"]], "Volumes": []]
        let valid = try parse([disk(), logical], info: ["disk4": metadata()], containers: [container])
        XCTAssertEqual(valid.count, 1)
        XCTAssertTrue(valid[0].selectable)
        XCTAssertTrue(valid[0].volumes.contains { $0.bsdName == "disk7s1" && $0.wholeBSDName == "disk4" })
        container["Volumes"] = [["DeviceIdentifier": "disk7s1", "Roles": ["System"]]]
        XCTAssertFalse(try parse([disk(), logical], info: ["disk4": metadata()], containers: [container])[0].selectable)
        XCTAssertFalse(try parse([disk(), logical], info: ["disk4": metadata()])[0].selectable)
    }
    func testAPFSContainerMissingFromListBlocksPhysicalDisk() throws {
        let container: [String: Any] = ["ContainerReference": "disk7", "PhysicalStores": [["DeviceIdentifier": "disk4s1"]]]
        XCTAssertFalse(try parse([disk()], info: ["disk4": metadata()], containers: [container])[0].selectable)
    }
    func testVolumeUUIDWithoutMediaWitnessIsRejected() throws {
        var value = disk()
        value["Partitions"] = [["DeviceIdentifier": "disk4s1", "VolumeUUID": uuidA]]
        XCTAssertEqual(try parse([value], info: ["disk4": metadata()])[0].rejectionReason, "inventory.identity")
    }
    func testUnresolvedAPFSPartitionIsRejected() throws {
        var value = disk()
        value["Partitions"] = [["DeviceIdentifier": "disk4s1", "DiskUUID": uuidA, "Content": "Apple_APFS"]]
        XCTAssertEqual(try parse([value], info: ["disk4": metadata()])[0].rejectionReason, "inventory.topology")
    }
    func testMultiStoreAPFSBlocksEveryBackingDisk() throws {
        let container: [String: Any] = ["ContainerReference": "disk7", "PhysicalStores": [["DeviceIdentifier": "disk4s1"], ["DeviceIdentifier": "disk9s1"]]]
        let targets = try parse([disk(), disk("disk9", uuid: uuidB)], info: ["disk4": metadata(), "disk9": metadata("disk9")], containers: [container])
        XCTAssertTrue(targets.allSatisfy { $0.rejectionReason == "inventory.topology" })
    }
    func testRootSnapshotBlockedEvenWhenReportedExternal() throws {
        var value = disk()
        value["Partitions"] = [["DeviceIdentifier": "disk4s1", "DiskUUID": uuidA,
                                "MountedSnapshots": [["SnapshotMountPoint": "/"]]]]
        XCTAssertEqual(try parse([value], info: ["disk4": metadata()])[0].rejectionReason, "inventory.system")
    }
    func testImageGroupingExcludesRootOwnedAndSystemImages() throws {
        var info = metadata()
        info["VirtualOrPhysical"] = "Virtual"
        info["BusProtocol"] = "Disk Image"
        var image: [String: Any] = ["image-path": "/Users/test/Downloads/Test.dmg", "owner-uid": 501,
                                    "system-entities": [["dev-entry": "/dev/disk4"], ["dev-entry": "/dev/disk4s1"]]]
        let valid = try parse([disk()], info: ["disk4": info], images: [image])[0]
        XCTAssertEqual(valid.kind, .diskImage)
        XCTAssertTrue(valid.selectable)
        image["owner-uid"] = 0
        XCTAssertFalse(try parse([disk()], info: ["disk4": info], images: [image])[0].selectable)
        image["owner-uid"] = 501
        image["image-path"] = "/System/Library/Test.dmg"
        XCTAssertFalse(try parse([disk()], info: ["disk4": info], images: [image])[0].selectable)
    }
    func testSanitizedLiveUSBAPFSFixtureGroupsOnPhysicalRoot() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "usb-apfs", withExtension: "plist", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let fixture = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let targets = try DiskTopology.targets(
            list: try XCTUnwrap(fixture["list"] as? [String: Any]),
            apfs: try XCTUnwrap(fixture["apfs"] as? [String: Any]),
            info: try XCTUnwrap(fixture["info"] as? [String: [String: Any]]),
            images: try XCTUnwrap(fixture["images"] as? [String: Any]), currentUserID: 501)
        XCTAssertEqual(targets.count, 1)
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.bsdName, "disk40")
        XCTAssertEqual(target.kind, .physical)
        XCTAssertTrue(target.selectable)
        XCTAssertEqual(target.mediaUUIDs.count, 2)
        XCTAssertTrue(target.volumes.contains { $0.bsdName.hasPrefix("disk41s") && $0.wholeBSDName == "disk40" })
        XCTAssertTrue(target.volumes.filter { $0.mountPath != nil }.allSatisfy { $0.volumeUUID != nil })
    }
    func testMalformedInventoryThrowsAndUnsafeBSDRejected() throws {
        XCTAssertThrowsError(try DiskTopology.targets(list: [:], apfs: [:], info: [:], images: [:], currentUserID: 501))
        XCTAssertFalse(DiskTopology.validBSD("disk4; touch /tmp/test"))
        XCTAssertFalse(DiskTopology.validBSD("disk4s1"))
        XCTAssertFalse(DiskTopology.validBSD("disk4\n"))
        XCTAssertTrue(DiskTopology.validBSD("disk42"))
    }
}
