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
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateLabels()
    }

    private func updateLabels() {
        item.button?.toolTip = Localization.text("status.tooltip")
        item.button?.setAccessibilityLabel(Localization.text("status.accessibility"))
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
        add(Localization.text("menu.foundation"), to: menu)
        add(Localization.text("menu.ejectionPlanned"), to: menu)
        menu.addItem(.separator())
        if let errorKey = inventory.errorKey { add(Localization.text(errorKey), to: menu) }
        if inventory.disks.isEmpty { add(Localization.text("inventory.empty"), to: menu) }
        for disk in inventory.disks {
            let label = Localization.text(disk.isKnownInternal ? "disk.internal" : "disk.unclassified")
            let entry = NSMenuItem(title: "\(disk.bsdName): \(label)", action: nil, keyEquivalent: "")
            let details = NSMenu()
            for volume in disk.volumes {
                add("\(volume.name) (\(volume.bsdName))", to: details)
                add(volume.mountPath ?? Localization.text("disk.notMounted"), to: details)
            }
            entry.submenu = details
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(settingsItem())
        let about = NSMenuItem(title: Localization.text("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: Localization.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func settingsItem() -> NSMenuItem {
        let settings = NSMenuItem(title: Localization.text("menu.settings"), action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()
        let language = NSMenuItem(title: Localization.text("settings.language"), action: nil, keyEquivalent: "")
        let languages = NSMenu()
        for choice in AppLanguage.allCases {
            let title: String
            switch choice {
            case .system: title = Localization.text("language.system")
            case .english: title = "English"
            case .french: title = "Français"
            }
            let entry = NSMenuItem(title: title, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = choice.rawValue
            entry.state = Localization.preferences.language == choice ? .on : .off
            languages.addItem(entry)
        }
        language.submenu = languages
        settingsMenu.addItem(language)
        settings.submenu = settingsMenu
        return settings
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let language = AppLanguage(rawValue: value) else { return }
        Localization.preferences.language = language
        updateLabels()
    }

    private func add(_ title: String, to menu: NSMenu) {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.isEnabled = false
        menu.addItem(entry)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = Localization.text("menu.about")
        alert.informativeText = Localization.text("about.description")
        alert.addButton(withTitle: Localization.text("button.ok"))
        alert.runModal()
    }
}
