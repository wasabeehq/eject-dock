import XCTest
@testable import EjectDockCore

final class UnmountVerificationTests: XCTestCase {
    private func target(mounted: Bool = false, snapshots: Bool = false, bsd: String = "disk9") -> InventoryTarget {
        InventoryTarget(stableID: "physical:test", bsdName: bsd, name: "Test", kind: .physical,
            volumes: [ObservedVolume(bsdName: bsd + "s1", wholeBSDName: bsd, name: "Test",
                mountPath: mounted ? "/Volumes/Test" : nil, isInternal: false)],
            hasMountedSnapshots: snapshots)
    }

    func testUnmountSucceedsWhileBackingDeviceRemainsConnected() {
        XCTAssertTrue(UnmountVerification.isConfirmed(target(mounted: true), in: [target()]))
        XCTAssertTrue(UnmountVerification.isConfirmed(target(), in: [target()]))
    }

    func testRemountSnapshotDisappearanceAndRecycledIdentityAreNotSuccess() {
        for inventory in [[target(mounted: true)], [target(snapshots: true)], [],
                          [target(), target()], [target(bsd: "disk10")]] {
            XCTAssertFalse(UnmountVerification.isConfirmed(target(), in: inventory))
        }
    }
}
