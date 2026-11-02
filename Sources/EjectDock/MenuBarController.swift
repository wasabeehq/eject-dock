import AppKit
import SwiftUI
import EjectDockCore

final class MenuBarController: NSObject {
    private enum RequestKind {
        case selected, dock(String), allExternal, allImages, single(String)
    }

    private enum Feedback {
        case ready
        case noSelectedConnected
        case noDockConnected
        case running([EjectionResult])
        case finished([EjectionResult], RequestKind)
        case loginItemError(String)
    }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let inventory: DiskInventory
    private let ejectionService: EjectionService
    private let preferences: PreferencesStore
    private let loginItemService: LoginItemService
    private var requestKind: RequestKind = .selected
    private var feedback: Feedback = .ready
    private let panel = NSPopover()
    private let panelModel = DiskPanelModel()
    private let toast = TransientToastController()
    private var activeDockSuccessToastID: String?

    init(inventory: DiskInventory, ejectionService: EjectionService,
         preferences: PreferencesStore, loginItemService: LoginItemService) {
        self.inventory = inventory
        self.ejectionService = ejectionService
        self.preferences = preferences
        self.loginItemService = loginItemService
        super.init()
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        inventory.onChange = { [weak self] in
            guard let self else { return }
            if self.inventory.isRefreshing {
                if self.activeDockSuccessToastID != nil {
                    self.toast.dismiss()
                    self.activeDockSuccessToastID = nil
                }
                if case .finished(let results, .dock) = self.feedback,
                   !results.isEmpty, results.allSatisfy({ $0.outcome == .success }) {
                    self.feedback = .ready
                }
            }
            self.preferences.refreshMetadata(from: InventorySnapshot(
                targets: self.inventory.targets,
                docks: self.inventory.docks
            ))
            self.reconcileFeedbackWithInventory()
            self.updateLabels()
        }
        ejectionService.onUpdate = { [weak self] state in self?.handle(state) }
        configurePanel()
        updateLabels()
    }

    private var connectedPhysicalTargets: [InventoryTarget] {
        inventory.targets.filter { $0.kind == .physical && $0.selectable }
    }

    private var connectedImageTargets: [InventoryTarget] {
        inventory.targets.filter { $0.kind == .diskImage && $0.selectable }
    }

    private var selectedConnectedTargets: [InventoryTarget] {
        let selected = Set(preferences.savedTargets.map(\.stableID))
        var targets = connectedPhysicalTargets.filter { selected.contains($0.stableID) }
        if preferences.includeDiskImages { targets.append(contentsOf: connectedImageTargets) }
        return targets
    }

    private var selectedDock: DockTarget? {
        guard case .dock(let saved) = preferences.primaryActionMode else { return nil }
        let matches = inventory.docks.filter { $0.stableID == saved.stableID }
        guard matches.count == 1, let dock = matches.first, dock.selectable else { return nil }
        return dock
    }

    private var hasConfiguredPrimaryAction: Bool {
        switch preferences.primaryActionMode {
        case .selectedDisks:
            return preferences.savedTargets.contains { $0.kind == .physical } || preferences.includeDiskImages
        case .dock:
            return true
        }
    }

    private var hasConnectedPrimaryAction: Bool {
        switch preferences.primaryActionMode {
        case .selectedDisks:
            return !selectedConnectedTargets.isEmpty
        case .dock:
            return selectedDock != nil
        }
    }

    private func updateLabels() {
        let title = feedbackTitle()
        let symbol: String
        switch feedback {
        case .ready:
            symbol = hasConfiguredPrimaryAction && !hasConnectedPrimaryAction
                ? "externaldrive.badge.questionmark" : "eject.circle"
        case .noSelectedConnected, .noDockConnected: symbol = "externaldrive.badge.questionmark"
        case .running: symbol = "arrow.triangle.2.circlepath.circle"
        case .finished(let results, _):
            symbol = !results.isEmpty && results.allSatisfy { $0.outcome == .success }
                ? "checkmark.circle" : "exclamationmark.triangle"
        case .loginItemError: symbol = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = title
        item.button?.setAccessibilityLabel(title)
        updatePanel()
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let action = MenuGesture.action(
            secondary: event?.type == .rightMouseUp,
            option: event?.modifierFlags.contains(.option) == true,
            control: event?.modifierFlags.contains(.control) == true,
            hasSelection: hasConfiguredPrimaryAction
        )
        if action == .openMenu {
            showMenu()
        } else {
            ejectPrimaryAction()
        }
    }

    func showMenu() {
        guard let button = item.button else { return }
        if panel.isShown { panel.performClose(nil); return }
        updatePanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        panel.contentViewController?.view.window?.makeKey()
    }

    private func configurePanel() {
        panel.behavior = .transient
        panel.animates = false
        panel.contentSize = NSSize(width: 410, height: 580)
        panel.contentViewController = NSHostingController(rootView: DiskPanelView(model: panelModel))
        panelModel.onSelected = { [weak self] in self?.ejectPrimaryAction() }
        panelModel.onAll = { [weak self] in self?.ejectAllExternal() }
        panelModel.onImages = { [weak self] in self?.ejectAllImages() }
        panelModel.onTarget = { [weak self] id in self?.ejectTarget(id) }
        panelModel.onSelection = { [weak self] id, selected in self?.setSelection(id, selected: selected) }
        panelModel.onPrimaryActionChoice = { [weak self] choice in self?.setPrimaryActionChoice(choice) }
        panelModel.onIncludeImages = { [weak self] in self?.toggleIncludeDiskImages() }
        panelModel.onLogin = { [weak self] in self?.toggleLaunchAtLogin() }
        panelModel.onLanguage = { [weak self] language in self?.changeLanguage(language) }
        panelModel.onAbout = { [weak self] in self?.panel.performClose(nil); self?.showAbout() }
        panelModel.onQuit = { NSApp.terminate(nil) }
        panelModel.onRefresh = { [weak self] in self?.inventory.refresh() }
    }

    private func updatePanel() {
        let busy = ejectionService.isRunning
        func row(_ target: InventoryTarget) -> DiskPanelRow {
            let mounts = target.volumes.compactMap(\.mountPath)
            let subtitle = target.selectable
                ? Localization.text(mounts.isEmpty ? "disk.notMounted" : "panel.mounted")
                : Localization.text(target.rejectionReason ?? "inventory.unknown")
            return DiskPanelRow(id: target.bsdName, stableID: target.stableID, name: target.name,
                subtitle: subtitle, detail: mounts.joined(separator: " · "),
                selected: preferences.isSelected(target.stableID),
                canSelect: target.selectable || preferences.isSelected(target.stableID),
                canOperate: target.selectable && !busy && (target.kind == .diskImage || !mounts.isEmpty),
                disconnected: false, image: target.kind == .diskImage)
        }
        let physical = inventory.targets.filter {
            $0.kind == .physical && $0.rejectionReason != "inventory.internal" && $0.rejectionReason != "inventory.system"
        }
        var rows = physical.map(row)
        let connectedIDs = Set(physical.map(\.stableID))
        for saved in preferences.savedTargets where saved.kind == .physical && !connectedIDs.contains(saved.stableID) {
            rows.append(DiskPanelRow(id: "saved:" + saved.stableID, stableID: saved.stableID,
                name: saved.name, subtitle: Localization.text("disk.disconnected"), detail: "",
                selected: true, canSelect: true, canOperate: false, disconnected: true, image: false))
        }
        panelModel.disks = rows
        panelModel.docks = inventory.docks.map { dock in
            DockPanelRow(
                id: dock.stableID,
                name: dock.name,
                detail: dock.selectable
                    ? Localization.format("panel.dockConnected", dock.memberTargetIDs.count)
                    : Localization.text("panel.dockUnavailable"),
                connected: true,
                selectable: dock.selectable
            )
        }
        if case .dock(let saved) = preferences.primaryActionMode,
           !panelModel.docks.contains(where: { $0.id == saved.stableID }) {
            panelModel.docks.append(DockPanelRow(
                id: saved.stableID,
                name: saved.name,
                detail: Localization.text("panel.dockDisconnected"),
                connected: false,
                selectable: false
            ))
        }
        panelModel.images = inventory.targets.filter {
            $0.kind == .diskImage && $0.rejectionReason != "inventory.system"
        }.map(row)
        panelModel.status = feedbackTitle()
        panelModel.busy = busy
        panelModel.refreshing = inventory.isRefreshing
        panelModel.inventoryError = inventory.errorKey.map(Localization.text)
        panelModel.warning = false
        panelModel.completed = false
        switch feedback {
        case .running(let results): panelModel.results = results.map(resultTitle)
        case .finished(let results, _):
            panelModel.results = results.map(resultTitle)
            panelModel.completed = !results.isEmpty && results.allSatisfy { $0.outcome == .success }
            panelModel.warning = !panelModel.completed
        case .loginItemError: panelModel.warning = true; panelModel.results = []
        default: panelModel.results = []
        }
        switch preferences.primaryActionMode {
        case .selectedDisks:
            panelModel.primaryActionChoice = .selectedDisks
            panelModel.primaryActionTitle = Localization.text("menu.ejectSelected")
            panelModel.canUnmountSelected = !busy && !selectedConnectedTargets.isEmpty
        case .dock(let saved):
            panelModel.primaryActionChoice = .dock(saved.stableID)
            panelModel.primaryActionTitle = Localization.text("menu.ejectDock")
            panelModel.canUnmountSelected = !busy && selectedDock != nil
        }
        panelModel.canUnmountAll = !busy && !connectedPhysicalTargets.isEmpty
        panelModel.canEjectImages = !busy && !connectedImageTargets.isEmpty
        panelModel.includeImages = preferences.includeDiskImages
        panelModel.language = Localization.preferences.language
        panelModel.loginEnabled = loginItemService.status == .enabled || loginItemService.status == .requiresApproval
        panelModel.loginAvailable = loginItemService.status != .unavailable
        panelModel.loginHint = loginItemService.status == .requiresApproval ? Localization.text("settings.loginApprovalRequired")
            : loginItemService.status == .unavailable ? Localization.text("settings.loginUnavailable") : nil
    }

    private func setSelection(_ stableID: String, selected: Bool) {
        guard !ejectionService.isRunning else { return }
        if let target = inventory.targets.first(where: { $0.stableID == stableID && $0.selectable && $0.kind == .physical }) {
            preferences.setSelected(target, selected: selected)
        } else if !selected, let saved = preferences.savedTargets.first(where: { $0.stableID == stableID }) {
            preferences.setSelected(saved, selected: false)
        }
        updateLabels()
    }

    private func setPrimaryActionChoice(_ choice: PrimaryActionChoice) {
        guard !ejectionService.isRunning else { return }
        switch choice {
        case .selectedDisks:
            preferences.useSelectedDisks()
        case .dock(let stableID):
            guard let dock = inventory.docks.first(where: { $0.stableID == stableID && $0.selectable }) else { return }
            preferences.selectDock(dock)
        }
        feedback = .ready
        updateLabels()
    }

    @objc private func ejectPrimaryAction() {
        guard !ejectionService.isRunning else { return }
        switch preferences.primaryActionMode {
        case .selectedDisks:
            startEjection(selectedConnectedTargets, kind: .selected)
        case .dock(let saved):
            guard let dock = selectedDock else {
                feedback = .noDockConnected
                updateLabels()
                showToast(message: Localization.text("status.dockFailed"), style: .failure)
                return
            }
            requestKind = .dock(saved.stableID)
            ejectionService.eject(dock)
        }
    }
    @objc private func ejectAllExternal() { startEjection(connectedPhysicalTargets, kind: .allExternal) }
    @objc private func ejectAllImages() { startEjection(connectedImageTargets, kind: .allImages) }

    private func ejectTarget(_ stableID: String) {
        guard let target = inventory.targets.first(where: { $0.stableID == stableID }) else { return }
        startEjection([target], kind: .single(target.name))
    }

    private func startEjection(_ targets: [InventoryTarget], kind: RequestKind) {
        guard !ejectionService.isRunning else { return }
        guard !targets.isEmpty else {
            feedback = .noSelectedConnected
            updateLabels()
            return
        }
        requestKind = kind
        ejectionService.eject(targets)
    }

    private func handle(_ state: EjectionBatchState) {
        precondition(Thread.isMainThread)
        switch state {
        case .idle: feedback = .ready
        case .running(let results): feedback = .running(results)
        case .finished(let results):
            let completedRequest = requestKind
            feedback = .finished(results, completedRequest)
            if case .dock(let expectedID) = completedRequest {
                let confirmed = results.count == 1 && results[0].targetID == expectedID && results[0].outcome == .success
                activeDockSuccessToastID = confirmed ? expectedID : nil
                showToast(
                    message: Localization.text(confirmed ? "status.dockReady" : "status.dockFailed"),
                    style: confirmed ? .success : .failure
                )
            }
            switch completedRequest {
            case .dock:
                break
            default:
                inventory.refresh()
            }
        }
        updateLabels()
    }

    private func reconcileFeedbackWithInventory() {
        guard !inventory.isRefreshing, inventory.errorKey == nil else { return }
        switch feedback {
        case .noSelectedConnected where !selectedConnectedTargets.isEmpty:
            feedback = .ready
        case .noDockConnected where selectedDock != nil:
            feedback = .ready
        case .finished(let results, _):
            let succeeded = Set(results.filter { $0.outcome == .success }.map(\.targetID))
            let remounted = inventory.targets.contains {
                succeeded.contains($0.stableID) && $0.volumes.contains { $0.mountPath != nil }
            }
            if remounted { feedback = .ready }
        default:
            break
        }
    }

    @objc private func toggleIncludeDiskImages() {
        preferences.includeDiskImages.toggle()
        updateLabels()
    }

    @objc private func toggleLaunchAtLogin() {
        guard !ejectionService.isRunning else { return }
        let shouldEnable: Bool
        switch loginItemService.status {
        case .enabled, .requiresApproval: shouldEnable = false
        case .disabled, .unavailable: shouldEnable = true
        }
        do {
            try loginItemService.setEnabled(shouldEnable)
            feedback = .ready
        } catch {
            feedback = .loginItemError(error.localizedDescription)
        }
        updateLabels()
    }

    private func changeLanguage(_ language: AppLanguage) {
        Localization.preferences.language = language
        updateLabels()
    }

    private func feedbackTitle() -> String {
        switch feedback {
        case .ready:
            if inventory.isRefreshing { return Localization.text("status.refreshing") }
            if hasConfiguredPrimaryAction && !hasConnectedPrimaryAction {
                return preferences.primaryActionMode == .selectedDisks
                    ? Localization.text("status.noSelectedConnected")
                    : Localization.text("status.noDockConnected")
            }
            return Localization.text("status.ready")
        case .noSelectedConnected: return Localization.text("status.noSelectedConnected")
        case .noDockConnected: return Localization.text("status.noDockConnected")
        case .loginItemError(let detail): return Localization.format("status.loginItemError", detail)
        case .running(let results):
            return results.contains(where: { $0.outcome == .pending })
                ? Localization.text("status.awaitingConfirmation") : Localization.format("status.ejecting", results.count)
        case .finished(let results, let kind):
            let successes = results.filter { $0.outcome == .success }.count
            let dockReadinessBlocked = results.contains {
                if case .dockReadinessBlocked = $0.outcome { return true }
                return false
            }
            let unmounted = results.contains {
                if case .nativeFailure(let failure) = $0.outcome { return failure.hasUnmountedVolumes }
                return false
            }
            if successes == results.count && !results.isEmpty {
                switch kind {
                case .selected: return Localization.text("status.selectedEjected")
                case .dock: return Localization.text("status.dockReady")
                case .allExternal: return Localization.text("status.allExternalEjected")
                case .allImages: return Localization.text("status.allImagesEjected")
                case .single(let name): return Localization.format("status.oneEjected", name)
                }
            }
            if dockReadinessBlocked { return Localization.text("status.dockReadinessBlocked") }
            if unmounted { return Localization.text("status.incompleteEjection") }
            return successes > 0 ? Localization.format("status.partial", successes, results.count)
                : Localization.text("status.noneEjected")
        }
    }

    private func showToast(message: String, style: TransientToastController.Style) {
        guard let button = item.button else { return }
        toast.show(message: message, style: style, anchoredTo: button)
    }

    private func resultTitle(_ result: EjectionResult) -> String {
        let detail: String
        switch result.outcome {
        case .working: detail = Localization.text("result.working")
        case .success: detail = Localization.text("result.success")
        case .unavailable: detail = Localization.text("result.unavailable")
        case .rejected: detail = Localization.text("result.rejected")
        case .pending: detail = Localization.text("result.pending")
        case .failed(let message): detail = Localization.format("result.failed", message)
        case .dockReadinessBlocked(let names):
            detail = Localization.format("result.dockReadinessBlocked", names.joined(separator: ", "))
        case .nativeFailure(let failure):
            let stage = Localization.text("native.stage." + failure.stage.rawValue)
            let reason = failure.isBusy ? Localization.format("native.busy", Int(failure.code))
                : Localization.format("native.error", Int(failure.code))
            let failureText = Localization.format("native.stageFailed", stage, reason)
            if failure.wholeUnmountSucceeded ||
                (failure.requestedVolumes > 0 && failure.unmountedVolumes == failure.requestedVolumes) {
                detail = Localization.format("native.volumesUnmounted", failureText)
            } else if failure.unmountedVolumes > 0 {
                detail = Localization.format("native.partialUnmount", failure.unmountedVolumes,
                                             failure.requestedVolumes, failureText)
            } else {
                detail = failureText
            }
        }
        return "\(result.name): \(detail)"
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
