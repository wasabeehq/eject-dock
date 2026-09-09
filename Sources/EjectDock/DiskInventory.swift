import Foundation
import DiskArbitration
import EjectDockCore

/// Read-only observer scheduled on the main run loop.
final class DiskInventory {
    private var session: DASession?
    private var records: [String: ObservedVolume] = [:]
    var onChange: (() -> Void)?
    private(set) var errorKey: String?
    var disks: [ObservedDisk] { InventoryGrouping.group(Array(records.values)) }

    func start() {
        guard session == nil else { return }
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            errorKey = "inventory.sessionError"
            onChange?()
            return
        }
        self.session = session
        let context = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(session, nil, { disk, context in
            guard let context else { return }
            Unmanaged<DiskInventory>.fromOpaque(context).takeUnretainedValue().update(disk)
        }, context)
        DARegisterDiskDisappearedCallback(session, nil, { disk, context in
            guard let context, let name = DADiskGetBSDName(disk) else { return }
            let owner = Unmanaged<DiskInventory>.fromOpaque(context).takeUnretainedValue()
            owner.records.removeValue(forKey: String(cString: name))
            owner.onChange?()
        }, context)
        DARegisterDiskDescriptionChangedCallback(session, nil, nil, { disk, _, context in
            guard let context else { return }
            Unmanaged<DiskInventory>.fromOpaque(context).takeUnretainedValue().update(disk)
        }, context)
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func stop() {
        guard let session else { return }
        DASessionUnscheduleFromRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        self.session = nil
        records.removeAll()
    }

    private func update(_ disk: DADisk) {
        guard let rawName = DADiskGetBSDName(disk),
              let description = DADiskCopyDescription(disk) as? [String: Any] else { return }
        let name = String(cString: rawName)
        let whole = DADiskCopyWholeDisk(disk) ?? disk
        let wholeName = DADiskGetBSDName(whole).map { String(cString: $0) } ?? name
        let wholeDescription = DADiskCopyDescription(whole) as? [String: Any] ?? [:]
        records[name] = ObservedVolume(
            bsdName: name, wholeBSDName: wholeName,
            name: description[kDADiskDescriptionVolumeNameKey as String] as? String
                ?? description[kDADiskDescriptionMediaNameKey as String] as? String ?? name,
            mountPath: (description[kDADiskDescriptionVolumePathKey as String] as? URL)?.path,
            isInternal: wholeDescription[kDADiskDescriptionDeviceInternalKey as String] as? Bool
                ?? description[kDADiskDescriptionDeviceInternalKey as String] as? Bool
        )
        onChange?()
    }
}
