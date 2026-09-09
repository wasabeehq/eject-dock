import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let inventory = DiskInventory()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(inventory: inventory)
        inventory.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        inventory.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
