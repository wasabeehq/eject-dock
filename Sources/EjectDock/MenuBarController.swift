import AppKit
import EjectDockCore

final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let inventory: DiskInventory

    init(inventory: DiskInventory) {
        self.inventory = inventory
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "eject.circle", accessibilityDescription: "EjectDock")
            button.image?.isTemplate = true
            button.toolTip = "EjectDock : inventaire en lecture seule"
            button.setAccessibilityLabel("EjectDock, ouvrir le menu des disques")
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let action = MenuGesture.action(
            secondary: event?.type == .rightMouseUp,
            option: event?.modifierFlags.contains(.option) == true,
            control: event?.modifierFlags.contains(.control) == true,
            hasSelection: false
        )
        if action == .openMenu { showMenu() }
    }

    private func showMenu() {
        let menu = NSMenu()
        add("EjectDock : socle en lecture seule", to: menu)
        add("Éjection disponible dans une prochaine phase", to: menu)
        menu.addItem(.separator())
        if let error = inventory.error { add(error, to: menu) }
        if inventory.disks.isEmpty { add("Aucun disque observé", to: menu) }
        for disk in inventory.disks {
            let label = disk.isKnownInternal ? "interne, exclu" : "type à qualifier"
            let entry = NSMenuItem(title: "\(disk.bsdName) : \(label)", action: nil, keyEquivalent: "")
            let details = NSMenu()
            for volume in disk.volumes {
                add("\(volume.name) (\(volume.bsdName))", to: details)
                add(volume.mountPath ?? "Non monté", to: details)
            }
            entry.submenu = details
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let about = NSMenuItem(title: "À propos", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: "Quitter EjectDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func add(_ title: String, to menu: NSMenu) {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.isEnabled = false
        menu.addItem(entry)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "EjectDock"])
    }
}
