import Foundation
import DiskArbitration
import EjectDockCore

/// Disk Arbitration triggers coalesced, read-only snapshots on a background queue.
final class DiskInventory {
    private var session: DASession?
    private let worker = DispatchQueue(label: "app.ejectdock.inventory", qos: .userInitiated)
    private var pendingRefresh: DispatchWorkItem?
    private var completions: [(Result<InventorySnapshot, Error>) -> Void] = []
    private var needsRefresh = false
    private var generation = 0
    var onChange: (() -> Void)?
    private(set) var errorKey: String?
    private(set) var targets: [InventoryTarget] = []
    private(set) var docks: [DockTarget] = []
    private(set) var isRefreshing = false
    var disks: [ObservedDisk] { InventoryGrouping.group(targets.flatMap(\.volumes)) }

    func start() {
        guard session == nil else { return }
        guard let created = DASessionCreate(kCFAllocatorDefault) else {
            errorKey = "inventory.sessionError"
            onChange?()
            return
        }
        session = created
        let context = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(created, nil, { _, context in
            guard let context else { return }
            Unmanaged<DiskInventory>.fromOpaque(context).takeUnretainedValue().scheduleRefresh()
        }, context)
        DARegisterDiskDisappearedCallback(created, nil, { _, context in
            guard let context else { return }
            Unmanaged<DiskInventory>.fromOpaque(context).takeUnretainedValue().scheduleRefresh()
        }, context)
        DARegisterDiskDescriptionChangedCallback(created, nil, nil, { _, _, context in
            guard let context else { return }
            Unmanaged<DiskInventory>.fromOpaque(context).takeUnretainedValue().scheduleRefresh()
        }, context)
        DASessionScheduleWithRunLoop(created, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        refresh()
    }

    func stop() {
        if let session {
            DASessionUnscheduleFromRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        session = nil
        pendingRefresh?.cancel()
        generation += 1
        targets = []
        docks = []
        isRefreshing = false
        let callbacks = completions
        completions.removeAll()
        callbacks.forEach { $0(.failure(InventoryCommand.Failure.commandFailed)) }
    }

    func refresh(completion: ((Result<InventorySnapshot, Error>) -> Void)? = nil) {
        precondition(Thread.isMainThread)
        if let completion { completions.append(completion) }
        guard !isRefreshing else { needsRefresh = true; return }
        pendingRefresh?.cancel()
        isRefreshing = true
        let currentGeneration = generation
        onChange?()
        worker.async { [weak self] in
            let result = Result { try Self.snapshot() }
            DispatchQueue.main.async {
                guard let self, self.generation == currentGeneration else { return }
                self.isRefreshing = false
                if self.needsRefresh {
                    self.needsRefresh = false
                    self.refresh()
                    return
                }
                switch result {
                case .success(let snapshot):
                    self.targets = snapshot.targets
                    self.docks = snapshot.docks
                    self.errorKey = nil
                case .failure:
                    self.targets = []
                    self.docks = []
                    self.errorKey = "inventory.refreshError"
                }
                let callbacks = self.completions
                self.completions.removeAll()
                self.onChange?()
                callbacks.forEach { $0(result) }
            }
        }
    }

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    /// Read-only and synchronous for diagnostics; call from a worker queue in the application.
    static func snapshot() throws -> InventorySnapshot {
        let list = try InventoryCommand.plist(executable: "/usr/sbin/diskutil", arguments: ["list", "-plist"])
        let apfs = try InventoryCommand.plist(executable: "/usr/sbin/diskutil", arguments: ["apfs", "list", "-plist"])
        let images = try DiskImageService().snapshot()
        var info: [String: [String: Any]] = [:]
        for disk in list["AllDisksAndPartitions"] as? [[String: Any]] ?? [] {
            guard let bsd = disk["DeviceIdentifier"] as? String, DiskTopology.validBSD(bsd),
                  disk["APFSPhysicalStores"] == nil else { continue }
            info[bsd] = try InventoryCommand.plist(executable: "/usr/sbin/diskutil", arguments: ["info", "-plist", bsd])
        }
        let targets = try DiskTopology.targets(
            list: list, apfs: apfs, info: info, images: images, currentUserID: getuid()
        )
        let observedDocks = IORegistryDockDiscovery.docks(for: targets)
        return InventorySnapshot(targets: targets, docks: DockTopology.targets(observed: observedDocks, inventory: targets))
    }
}
