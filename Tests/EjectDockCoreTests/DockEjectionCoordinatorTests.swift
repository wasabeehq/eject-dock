import XCTest
@testable import EjectDockCore

final class DockEjectionCoordinatorTests: XCTestCase {
    private func disk(_ id: String, bsd: String, mounted: Bool) -> InventoryTarget {
        InventoryTarget(stableID: id, bsdName: bsd, name: id, kind: .physical,
                        volumes: [ObservedVolume(bsdName: bsd + "s1", wholeBSDName: bsd,
                            name: id, mountPath: mounted ? "/Volumes/\(id)" : nil, isInternal: false)])
    }

    private func dock(_ ids: [String]) -> DockTarget {
        DockTarget(stableID: "dock:1", name: "Dock", persistence: .sessionOnly,
                   memberTargetIDs: ids, boundaryIDs: [1])
    }

    func testNewArrivalIsUnmountedBeforeFreshWholeDockSuccess() {
        let mountedA = disk("A", bsd: "disk8", mounted: true)
        let unmountedA = disk("A", bsd: "disk8", mounted: false)
        let mountedB = disk("B", bsd: "disk9", mounted: true)
        let unmountedB = disk("B", bsd: "disk9", mounted: false)
        let firstDock = dock(["A"])
        let expandedDock = dock(["A", "B"])
        var snapshots = [
            InventorySnapshot(targets: [mountedA], docks: [firstDock]),
            InventorySnapshot(targets: [unmountedA, mountedB], docks: [expandedDock]),
            InventorySnapshot(targets: [unmountedA, unmountedB], docks: [expandedDock])
        ]
        var performed: [String] = []
        let coordinator = DockEjectionCoordinator(
            refresh: { $0(.success(snapshots.removeFirst())) },
            perform: { target, completion in performed.append(target.stableID); completion(.success) },
            schedule: { _, _ in }
        )
        XCTAssertTrue(coordinator.eject(firstDock))
        XCTAssertEqual(performed, ["A", "B"])
        XCTAssertEqual(coordinator.state, .finished([
            EjectionResult(targetID: firstDock.stableID, name: firstDock.name, outcome: .success)
        ]))
    }

    func testAbsentDockCannotSucceed() {
        let requested = dock(["A"])
        var performed = false
        let coordinator = DockEjectionCoordinator(
            refresh: { $0(.success(InventorySnapshot(targets: [], docks: []))) },
            perform: { _, _ in performed = true }, schedule: { _, _ in }
        )
        coordinator.eject(requested)
        XCTAssertFalse(performed)
        XCTAssertEqual(coordinator.state, .finished([
            EjectionResult(targetID: requested.stableID, name: requested.name, outcome: .unavailable)
        ]))
    }

    func testOtherMountedExternalDiskReturnsTypedReadinessFailureWithoutUnmountingIt() {
        let member = disk("A", bsd: "disk8", mounted: false)
        let other = disk("B", bsd: "disk9", mounted: true)
        let requested = dock(["A"])
        var performed: [String] = []
        let coordinator = DockEjectionCoordinator(
            refresh: { $0(.success(InventorySnapshot(targets: [member, other], docks: [requested]))) },
            perform: { target, _ in performed.append(target.stableID) }, schedule: { _, _ in }
        )
        coordinator.eject(requested)
        XCTAssertTrue(performed.isEmpty)
        XCTAssertEqual(coordinator.state, .finished([
            EjectionResult(targetID: requested.stableID, name: requested.name,
                           outcome: .dockReadinessBlocked(["B"]))
        ]))
    }

    func testTimeoutIsPendingAndDoesNotUnlockOperation() {
        let requested = dock(["A"])
        var timer: (() -> Void)?
        var refresh: ((Result<InventorySnapshot, Error>) -> Void)?
        let coordinator = DockEjectionCoordinator(
            refresh: { refresh = $0 }, perform: { _, _ in }, schedule: { _, action in timer = action }
        )
        XCTAssertTrue(coordinator.eject(requested))
        timer?()
        XCTAssertTrue(coordinator.isRunning)
        XCTAssertFalse(coordinator.eject(requested))
        XCTAssertEqual(coordinator.state, .running([
            EjectionResult(targetID: requested.stableID, name: requested.name, outcome: .pending)
        ]))
        refresh?(.success(InventorySnapshot(targets: [], docks: [])))
        XCTAssertFalse(coordinator.isRunning)
    }

    func testPersistentIdentityCannotSwitchPhysicalBoundaryDuringOperation() {
        let requested = DockTarget(stableID: "dock:persistent", name: "Dock", persistence: .persistent,
                                   memberTargetIDs: ["A"], boundaryIDs: [1])
        let replacement = DockTarget(stableID: requested.stableID, name: "Dock", persistence: .persistent,
                                     memberTargetIDs: ["A"], boundaryIDs: [2])
        let member = disk("A", bsd: "disk8", mounted: true)
        var performed = false
        let coordinator = DockEjectionCoordinator(
            refresh: { $0(.success(InventorySnapshot(targets: [member], docks: [replacement]))) },
            perform: { _, _ in performed = true }, schedule: { _, _ in }
        )
        coordinator.eject(requested)
        XCTAssertFalse(performed)
        XCTAssertEqual(coordinator.state, .finished([
            EjectionResult(targetID: requested.stableID, name: requested.name, outcome: .rejected)
        ]))
    }
}
