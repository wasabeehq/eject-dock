import XCTest
@testable import EjectDockCore

final class NativeEjectionFailureTests: XCTestCase {
    func testPartialUnmountIsPreservedWithoutClaimingEjectionSuccess() {
        let target = InventoryTarget(stableID: "test", bsdName: "disk9", name: "Test", kind: .physical, volumes: [])
        let failure = NativeEjectionFailure(stage: .eject, code: 49168, unmountedVolumes: 1,
            requestedVolumes: 1, wholeUnmountSucceeded: true, detail: nil)
        let coordinator = EjectionCoordinator(refresh: { $0(.success([target])) },
            perform: { _, completion in completion(.nativeFailure(failure)) }, schedule: { _, _ in })
        coordinator.eject([target])
        XCTAssertFalse(coordinator.isRunning)
        XCTAssertTrue(failure.hasUnmountedVolumes)
        XCTAssertEqual(coordinator.state, .finished([
            EjectionResult(targetID: "test", name: "Test", outcome: .nativeFailure(failure))
        ]))
    }

    func testBusyEncodingsAndFailureBeforeAnyProgress() {
        for code: UInt32 in [0xF8DA0002, 49168] {
            let failure = NativeEjectionFailure(stage: .volumeUnmount, code: code,
                unmountedVolumes: 0, requestedVolumes: 1, wholeUnmountSucceeded: false, detail: nil)
            XCTAssertTrue(failure.isBusy)
            XCTAssertFalse(failure.hasUnmountedVolumes)
        }
        let failure = NativeEjectionFailure(stage: .wholeUnmount, code: 1,
            unmountedVolumes: 1, requestedVolumes: 2, wholeUnmountSucceeded: false, detail: nil)
        XCTAssertFalse(failure.isBusy)
        XCTAssertTrue(failure.hasUnmountedVolumes)
    }
}
