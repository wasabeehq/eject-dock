import Foundation
import DiskArbitration
import EjectDockCore
import OSLog

/// The UI and the coordinator remain on the main queue. Only image detachment
/// runs on a worker queue; native callbacks use the main run loop.
final class EjectionService {
    private let inventory: DiskInventory
    private let operations = NativeEjectionOperations()
    private lazy var coordinator = EjectionCoordinator(
        refresh: { [weak self] completion in
            guard let self else { return }
            self.inventory.refresh { completion($0.map(\.targets)) }
        },
        perform: { [weak self] target, completion in
            self?.operations.perform(target) { outcome in
                completion(outcome)
                self?.inventory.refresh()
            }
        },
        schedule: { interval, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: action)
        }
    )
    private lazy var dockCoordinator = DockEjectionCoordinator(
        refresh: { [weak self] completion in
            guard let self else { return }
            self.inventory.refresh(completion: completion)
        },
        perform: { [weak self] target, completion in
            self?.operations.perform(target) { outcome in
                completion(outcome)
                self?.inventory.refresh()
            }
        },
        schedule: { interval, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: action)
        }
    )

    init(inventory: DiskInventory) { self.inventory = inventory }
    var isRunning: Bool { coordinator.isRunning || dockCoordinator.isRunning }
    var onUpdate: ((EjectionBatchState) -> Void)? {
        get { coordinator.onUpdate ?? dockCoordinator.onUpdate }
        set {
            coordinator.onUpdate = newValue
            dockCoordinator.onUpdate = newValue
        }
    }
    func eject(_ targets: [InventoryTarget]) {
        guard !isRunning else { return }
        coordinator.eject(targets)
    }
    func eject(_ dock: DockTarget) {
        guard !isRunning else { return }
        dockCoordinator.eject(dock)
    }
}

final class NativeEjectionOperations {
    private let session: DASession? = DASessionCreate(kCFAllocatorDefault)
    init() {
        if let session {
            DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
    }
    deinit {
        if let session {
            DASessionUnscheduleFromRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
    }

    func perform(_ target: InventoryTarget, useDiskArbitrationForTestImage: Bool = false,
                 completion: @escaping (EjectionOutcome) -> Void) {
        guard target.selectable else { completion(.rejected); return }
        let disposableImageTest = useDiskArbitrationForTestImage && target.kind == .diskImage &&
            target.volumes.contains { volume in
                volume.mountPath.map { URL(fileURLWithPath: $0).lastPathComponent.hasPrefix("EjectDockTest-") } == true
            }
        if useDiskArbitrationForTestImage && !disposableImageTest { completion(.rejected); return }
        if target.kind == .diskImage && !disposableImageTest {
            detachImage(target, completion: completion)
            return
        }
        guard let session,
              let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, "/dev/" + target.bsdName),
              let description = DADiskCopyDescription(disk) as? [String: Any],
              (description[kDADiskDescriptionDeviceInternalKey as String] as? Bool == false || disposableImageTest),
              description[kDADiskDescriptionMediaWholeKey as String] as? Bool == true else {
            completion(.rejected)
            return
        }
        // Pin all handles and verify identity witnesses before the first unmount.
        guard !target.mediaUUIDs.isEmpty else { completion(.rejected); return }
        var witnesses: [DADisk] = []
        for (bsdName, expected) in target.mediaUUIDs {
            guard let witness = DADiskCreateFromBSDName(kCFAllocatorDefault, session, "/dev/" + bsdName),
                  let info = DADiskCopyDescription(witness) as? [String: Any],
                  let value = info[kDADiskDescriptionMediaUUIDKey as String],
                  CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID() else {
                completion(.rejected)
                return
            }
            let uuid = CFUUIDCreateString(kCFAllocatorDefault, unsafeBitCast(value as AnyObject, to: CFUUID.self)) as String
            guard uuid.caseInsensitiveCompare(expected) == .orderedSame else {
                completion(.rejected)
                return
            }
            witnesses.append(witness)
        }
        var volumes: [DADisk] = []
        for volume in target.volumes where volume.mountPath != nil {
            guard volume.mountPath != "/",
                  let expectedUUID = volume.volumeUUID,
                  let handle = DADiskCreateFromBSDName(kCFAllocatorDefault, session, "/dev/" + volume.bsdName),
                  let info = DADiskCopyDescription(handle) as? [String: Any],
                  let value = info[kDADiskDescriptionVolumeUUIDKey as String],
                  CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID(),
                  let path = info[kDADiskDescriptionVolumePathKey as String] as? URL,
                  path.path == volume.mountPath, path.path != "/", !path.path.hasPrefix("/System/") else {
                completion(.rejected)
                return
            }
            let uuid = CFUUIDCreateString(kCFAllocatorDefault, unsafeBitCast(value as AnyObject, to: CFUUID.self)) as String
            guard uuid.caseInsensitiveCompare(expectedUUID) == .orderedSame else {
                completion(.rejected)
                return
            }
            volumes.append(handle)
        }
        let operation = PhysicalUnmount(disk: disk, volumes: volumes, witnesses: witnesses) { outcome in
            guard outcome == .success else { completion(outcome); return }
            DispatchQueue.global(qos: .userInitiated).async {
                let confirmed = (try? DiskInventory.snapshot()).map {
                    UnmountVerification.isConfirmed(target, in: $0.targets)
                } ?? false
                DispatchQueue.main.async {
                    completion(confirmed ? .success : .failed(Localization.text("native.verificationFailed")))
                }
            }
        }
        operation.next()
    }

    private func detachImage(_ target: InventoryTarget, completion: @escaping (EjectionOutcome) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Recheck on the worker immediately before invoking the BSD-based tool.
            // Queuing work must not extend the lifetime of a stale image identity.
            do {
                let matches = try DiskInventory.snapshot().targets.filter { $0.stableID == target.stableID }
                guard matches.count == 1, let current = matches.first,
                      current.selectable, current.kind == .diskImage,
                      current.bsdName == target.bsdName, current.mediaUUIDs == target.mediaUUIDs else {
                    DispatchQueue.main.async { completion(.rejected) }
                    return
                }
            } catch {
                DispatchQueue.main.async { completion(.failed(error.localizedDescription)) }
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = ["detach", "/dev/" + target.bsdName]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let outcome: EjectionOutcome = process.terminationStatus == 0
                    ? .success : .failed(detail.isEmpty ? "hdiutil: \(process.terminationStatus)" : detail)
                DispatchQueue.main.async { completion(outcome) }
            } catch {
                DispatchQueue.main.async { completion(.failed(error.localizedDescription)) }
            }
        }
    }
}

/// A retained context is consumed exactly once by each native callback.
private final class PhysicalUnmount {
    let disk: DADisk
    var volumes: [DADisk]
    let witnesses: [DADisk]
    let completion: (EjectionOutcome) -> Void
    private var unmountedVolumes = 0
    private let requestedVolumes: Int
    private var stage: NativeEjectionFailure.Stage = .volumeUnmount
    private let logger = Logger(subsystem: "fr.wasabee.ejectdock", category: "ejection")

    init(disk: DADisk, volumes: [DADisk], witnesses: [DADisk], completion: @escaping (EjectionOutcome) -> Void) {
        self.disk = disk
        self.volumes = volumes
        self.requestedVolumes = volumes.count
        self.witnesses = witnesses
        self.completion = completion
    }

    func next() {
        if !volumes.isEmpty {
            stage = .volumeUnmount
            let volume = volumes.removeFirst()
            DADiskUnmount(volume, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { _, dissenter, context in
                guard let context else { return }
                let owner = Unmanaged<PhysicalUnmount>.fromOpaque(context).takeRetainedValue()
                if let dissenter { owner.fail(dissenter) } else {
                    owner.unmountedVolumes += 1
                    owner.next()
                }
            }, Unmanaged.passRetained(self).toOpaque())
        } else {
            // Every captured mounted volume has confirmed normal unmount.
            // The caller refreshes topology before reporting success.
            completion(.success)
        }
    }

    private func fail(_ dissenter: DADissenter) {
        let detail = DADissenterGetStatusString(dissenter) as String?
        let code = UInt32(bitPattern: DADissenterGetStatus(dissenter))
        logger.error("Native failure: stage=\(self.stage.rawValue, privacy: .public) code=\(code) unmounted=\(self.unmountedVolumes)/\(self.requestedVolumes)")
        completion(.nativeFailure(NativeEjectionFailure(stage: stage, code: code,
            unmountedVolumes: unmountedVolumes, requestedVolumes: requestedVolumes,
            wholeUnmountSucceeded: false, detail: detail)))
    }
}
