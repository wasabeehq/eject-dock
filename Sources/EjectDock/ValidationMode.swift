import AppKit
import Foundation
import EjectDockCore

private final class ToastPreviewDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toast = TransientToastController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = item.button else { exit(1) }
        let failure = CommandLine.arguments.contains("failure")
        button.image = NSImage(systemSymbolName: "eject.circle", accessibilityDescription: "EjectDock")
        button.image?.isTemplate = true
        DispatchQueue.main.async { [toast] in
            toast.show(
                message: Localization.text(failure ? "status.dockFailed" : "status.dockReady"),
                style: failure ? .failure : .success,
                anchoredTo: button
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { NSApp.terminate(nil) }
    }
}

func runToastPreviewMode() -> Never {
    let app = NSApplication.shared
    let delegate = ToastPreviewDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
    exit(0)
}

/// Explicit command-line diagnostics. Normal application launch never enters this path.
func runValidationMode() -> Never {
    let inventory = DiskInventory()
    let service = EjectionService(inventory: inventory)
    let native = NativeEjectionOperations()
    let arguments = CommandLine.arguments
    inventory.refresh { result in
        switch result {
        case .failure(let error):
            print("Inventory failed: \(error)")
            exit(1)
        case .success(let snapshot):
            let targets = snapshot.targets
            if arguments.contains("--validate-inventory") {
                for target in targets {
                    print("\(target.bsdName) \(target.kind.rawValue) eligible=\(target.selectable) volumes=\(target.volumes.count) witnesses=\(target.mediaUUIDs.count) reason=\(target.rejectionReason ?? "none")")
                }
                exit(0)
            }
            guard let flag = arguments.firstIndex(of: "--test-eject-image"), arguments.indices.contains(flag + 1) else {
                print("Provide the mount path of a disposable EjectDockTest image.")
                exit(2)
            }
            let mountPath = arguments[flag + 1]
            // The test adapter only accepts a mounted image deliberately named by the test script.
            guard URL(fileURLWithPath: mountPath).lastPathComponent.hasPrefix("EjectDockTest-"),
                  let target = targets.first(where: { target in
                      target.kind == .diskImage && target.selectable &&
                      target.volumes.contains { $0.mountPath == mountPath }
                  }) else {
                print("Disposable eligible image not found.")
                exit(2)
            }
            service.onUpdate = { state in
                switch state {
                case .idle: break
                case .running(let results):
                    if results.contains(where: { $0.outcome == .pending }) {
                        print("Image operation remains pending.")
                    }
                case .finished(let results):
                    guard results.count == 1, results[0].outcome == .success else {
                        print("Image test result: \(results)")
                        exit(1)
                    }
                    inventory.refresh { verified in
                        guard case .success(let refreshed) = verified else {
                            print("Inventory verification failed.")
                            exit(1)
                        }
                        if arguments.contains("--physical-adapter") {
                            guard UnmountVerification.isConfirmed(target, in: refreshed.targets) else {
                                print("Volume unmount was not confirmed.")
                                exit(1)
                            }
                            print("Disposable volumes unmounted; backing device remains present.")
                            exit(0)
                        }
                        guard !refreshed.targets.contains(where: { $0.bsdName == target.bsdName }) else {
                            print("Image is still present or verification failed.")
                            exit(1)
                        }
                        print("Disposable image detached and absence verified.")
                        exit(0)
                    }
                }
            }
            if arguments.contains("--physical-adapter") {
                native.perform(target, useDiskArbitrationForTestImage: true) { outcome in
                    service.onUpdate?(.finished([EjectionResult(targetID: target.stableID,
                                                               name: target.name, outcome: outcome)]))
                }
            } else {
                service.eject([target])
            }
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 90) {
        print("Validation timed out; no success assumed.")
        exit(1)
    }
    RunLoop.main.run()
    exit(1)
}
