import XCTest
@testable import EjectDockCore

final class EjectionCoordinatorTests: XCTestCase {
    private func target(_ id: String = "A", bsd: String = "disk8", selectable: Bool = true) -> InventoryTarget {
        InventoryTarget(stableID: id, bsdName: bsd, name: "Same name", kind: .physical,
                        volumes: [], selectable: selectable)
    }

    func testRevalidatesIdentityAndRejectsReusedBSDName() {
        let original = target()
        var performed = false
        let service = EjectionCoordinator(refresh: { $0(.success([self.target("B")])) },
            perform: { _, _ in performed = true }, schedule: { _, _ in })
        service.eject([original])
        XCTAssertFalse(performed)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.state, .finished([EjectionResult(targetID: "A", name: "Same name", outcome: .unavailable)]))
    }

    func testRejectsChangedLocationAndCollisionsAndIneligibleTargets() {
        for current in [[target(bsd: "disk9")], [target(), target()], [target(selectable: false)]] {
            var performed = false
            let service = EjectionCoordinator(refresh: { $0(.success(current)) },
                perform: { _, _ in performed = true }, schedule: { _, _ in })
            service.eject([target()])
            XCTAssertFalse(performed)
            XCTAssertEqual(service.state, .finished([EjectionResult(targetID: "A", name: "Same name", outcome: .rejected)]))
        }
    }

    func testPartialFailureDoesNotBlockOtherTargets() {
        let targets = [target(), target("B", bsd: "disk9")]
        var callbacks: [String: (EjectionOutcome) -> Void] = [:]
        let service = EjectionCoordinator(refresh: { $0(.success(targets)) },
            perform: { target, callback in callbacks[target.stableID] = callback }, schedule: { _, _ in })
        service.eject(targets)
        XCTAssertEqual(callbacks.count, 2)
        callbacks["B"]?(.success)
        XCTAssertTrue(service.isRunning)
        callbacks["A"]?(.failed("busy"))
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.state, .finished([
            EjectionResult(targetID: "A", name: "Same name", outcome: .failed("busy")),
            EjectionResult(targetID: "B", name: "Same name", outcome: .success)
        ]))
    }

    func testTimeoutKeepsLockAndLateCallbackSettles() {
        var timer: (() -> Void)?
        var callback: ((EjectionOutcome) -> Void)?
        let disk = target()
        let service = EjectionCoordinator(refresh: { $0(.success([disk])) },
            perform: { _, completion in callback = completion }, schedule: { _, action in timer = action })
        XCTAssertTrue(service.eject([disk]))
        timer?()
        XCTAssertTrue(service.isRunning)
        XCTAssertFalse(service.eject([disk]))
        XCTAssertEqual(service.state, .running([EjectionResult(targetID: "A", name: "Same name", outcome: .pending)]))
        callback?(.success)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.state, .finished([EjectionResult(targetID: "A", name: "Same name", outcome: .success)]))
        callback?(.failed("duplicate callback"))
        XCTAssertEqual(service.state, .finished([EjectionResult(targetID: "A", name: "Same name", outcome: .success)]))
    }

    func testDuplicateClicksAndDuplicateRequestsCannotPerformTwice() {
        let disk = target()
        var operations = 0
        let service = EjectionCoordinator(refresh: { $0(.success([disk])) },
            perform: { _, _ in operations += 1 }, schedule: { _, _ in })
        XCTAssertTrue(service.eject([disk, disk]))
        XCTAssertFalse(service.eject([disk]))
        XCTAssertEqual(operations, 1)
    }

    func testEmptyBatchAndRefreshFailure() {
        let service = EjectionCoordinator(refresh: { $0(.failure(NSError(domain: "test", code: 1))) },
            perform: { _, _ in XCTFail("Must not perform after a failed inventory") }, schedule: { _, _ in })
        service.eject([])
        XCTAssertEqual(service.state, .finished([]))
        service.eject([target()])
        XCTAssertFalse(service.isRunning)
        guard case .finished(let results) = service.state, case .failed = results.first?.outcome else {
            return XCTFail("Expected an explicit failure")
        }
    }

    func testTimeoutDuringInventoryKeepsLockUntilRefreshSettles() {
        let disk = target()
        var timer: (() -> Void)?
        var refreshed: ((Result<[InventoryTarget], Error>) -> Void)?
        var operations = 0
        let service = EjectionCoordinator(refresh: { refreshed = $0 },
            perform: { _, completion in operations += 1; completion(.success) },
            schedule: { _, action in timer = action })
        XCTAssertTrue(service.eject([disk]))
        timer?()
        XCTAssertTrue(service.isRunning)
        XCTAssertFalse(service.eject([disk]))
        XCTAssertEqual(operations, 0)
        XCTAssertEqual(service.state, .running([EjectionResult(targetID: "A", name: "Same name", outcome: .pending)]))
        refreshed?(.success([disk]))
        XCTAssertEqual(operations, 1)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.state, .finished([EjectionResult(targetID: "A", name: "Same name", outcome: .success)]))
    }

    func testPriorBatchTimeoutCannotMutateNewOperationForSameTarget() {
        let disk = target()
        var timers: [() -> Void] = []
        var callbacks: [(EjectionOutcome) -> Void] = []
        let service = EjectionCoordinator(refresh: { $0(.success([disk])) },
            perform: { _, callback in callbacks.append(callback) },
            schedule: { _, action in timers.append(action) })
        XCTAssertTrue(service.eject([disk]))
        callbacks[0](.success)
        XCTAssertTrue(service.eject([disk]))
        timers[0]()
        callbacks[0](.failed("duplicate old completion"))
        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(service.state, .running([EjectionResult(targetID: "A", name: "Same name", outcome: .working)]))
        timers[1]()
        XCTAssertEqual(service.state, .running([EjectionResult(targetID: "A", name: "Same name", outcome: .pending)]))
        callbacks[1](.success)
        XCTAssertFalse(service.isRunning)
    }
}
