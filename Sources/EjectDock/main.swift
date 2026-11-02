import AppKit
import EjectDockCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let inventory = DiskInventory()
    private let preferences = PreferencesStore()
    private let loginItemService = LoginItemService()
    private var menuBar: MenuBarController?
    private lazy var ejectionService = EjectionService(inventory: inventory)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: "fr.leo.ejectdock")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
        if !otherInstances.isEmpty {
            NSApp.terminate(nil)
            return
        }
        menuBar = MenuBarController(
            inventory: inventory,
            ejectionService: ejectionService,
            preferences: preferences,
            loginItemService: loginItemService
        )
        inventory.start()
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.async { [weak self] in self?.menuBar?.showMenu() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        inventory.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ejectionService.isRunning ? .terminateCancel : .terminateNow
    }

}

if CommandLine.arguments.contains("--preview-toast") {
    runToastPreviewMode()
}

if CommandLine.arguments.contains("--validate-inventory") ||
    CommandLine.arguments.contains("--test-eject-image") {
    runValidationMode()
}

let instanceLock: SingleInstanceLock
do {
    instanceLock = try SingleInstanceLock()
} catch SingleInstanceLock.Failure.alreadyRunning {
    exit(0)
} catch {
    fputs("Could not acquire the application instance lock.\n", stderr)
    exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
