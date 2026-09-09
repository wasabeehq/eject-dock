import XCTest
@testable import EjectDockCore

final class CoreTests: XCTestCase {
    func testVolumesShareWholeDiskButNamesDoNotIdentifyDisks() {
        let volumes = [
            ObservedVolume(bsdName: "disk4s1", wholeBSDName: "disk4", name: "Backup", mountPath: nil, isInternal: false),
            ObservedVolume(bsdName: "disk4s2", wholeBSDName: "disk4", name: "Data", mountPath: nil, isInternal: false),
            ObservedVolume(bsdName: "disk5s1", wholeBSDName: "disk5", name: "Backup", mountPath: nil, isInternal: nil)
        ]
        let groups = InventoryGrouping.group(volumes)
        XCTAssertEqual(groups.map(\.bsdName), ["disk4", "disk5"])
        XCTAssertEqual(groups.map { $0.volumes.count }, [2, 1])
    }

    func testInternalFlagPropagatesToGroup() {
        let groups = InventoryGrouping.group([
            ObservedVolume(bsdName: "disk0s1", wholeBSDName: "disk0", name: "System", mountPath: "/", isInternal: true)
        ])
        XCTAssertTrue(groups[0].isKnownInternal)
    }

    func testGestures() {
        XCTAssertEqual(MenuGesture.action(secondary: false, option: false, control: false, hasSelection: false), .openMenu)
        XCTAssertEqual(MenuGesture.action(secondary: false, option: false, control: false, hasSelection: true), .ejectSelection)
        XCTAssertEqual(MenuGesture.action(secondary: true, option: false, control: false, hasSelection: true), .openMenu)
        XCTAssertEqual(MenuGesture.action(secondary: false, option: true, control: false, hasSelection: true), .openMenu)
        XCTAssertEqual(MenuGesture.action(secondary: false, option: false, control: true, hasSelection: true), .openMenu)
    }
}
