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
        func action(_ secondary: Bool, _ option: Bool, _ control: Bool, _ selected: Bool) -> MenuGesture.Action {
            MenuGesture.action(secondary: secondary, option: option, control: control, hasSelection: selected)
        }
        XCTAssertEqual(action(false, false, false, true), .openMenu)
        XCTAssertEqual(action(false, false, false, false), .openMenu)
        XCTAssertEqual(action(true, false, false, true), .ejectSelection)
        XCTAssertEqual(action(true, false, false, false), .openMenu)
        XCTAssertEqual(action(false, false, true, true), .ejectSelection)
        XCTAssertEqual(action(false, false, true, false), .openMenu)
        XCTAssertEqual(action(false, true, false, true), .openMenu)
        XCTAssertEqual(action(false, true, false, false), .openMenu)
        XCTAssertEqual(action(true, true, false, true), .openMenu)
        XCTAssertEqual(action(false, true, true, true), .openMenu)
    }
}
