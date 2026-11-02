import Foundation

public enum EjectionOutcome: Equatable {
    case working, success, unavailable, rejected, failed(String), pending
    case nativeFailure(NativeEjectionFailure)
    case dockReadinessBlocked([String])
}

public struct EjectionResult: Equatable {
    public let targetID: String
    public let name: String
    public var outcome: EjectionOutcome

    public init(targetID: String, name: String, outcome: EjectionOutcome) {
        self.targetID = targetID
        self.name = name
        self.outcome = outcome
    }
}

public enum EjectionBatchState: Equatable {
    case idle
    case running([EjectionResult])
    case finished([EjectionResult])
}

/// All dependencies must call back on the same serial queue as the caller.
/// A timeout reports uncertainty while preserving the operation lock.
public final class EjectionCoordinator {
    public typealias Refresh = (@escaping (Result<[InventoryTarget], Error>) -> Void) -> Void
    public typealias Perform = (InventoryTarget, @escaping (EjectionOutcome) -> Void) -> Void
    public typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void

    private let refresh: Refresh
    private let perform: Perform
    private let schedule: Schedule
    private let timeout: TimeInterval
    private var generation = UUID()
    private var results: [EjectionResult] = []
    private var outstanding: Set<String> = []
    public private(set) var isRunning = false
    public private(set) var state: EjectionBatchState = .idle
    public var onUpdate: ((EjectionBatchState) -> Void)?

    public init(timeout: TimeInterval = 30, refresh: @escaping Refresh,
                perform: @escaping Perform, schedule: @escaping Schedule) {
        self.timeout = timeout
        self.refresh = refresh
        self.perform = perform
        self.schedule = schedule
    }

    @discardableResult
    public func eject(_ requested: [InventoryTarget]) -> Bool {
        guard !isRunning else { return false }
        generation = UUID()
        let batch = generation
        var seen: Set<String> = []
        let targets = requested.filter { seen.insert($0.stableID).inserted }
        results = targets.map { EjectionResult(targetID: $0.stableID, name: $0.name, outcome: .working) }
        outstanding = Set(targets.map(\.stableID))
        isRunning = !targets.isEmpty
        publish()
        for target in targets {
            guard target.selectable else {
                complete(target.stableID, outcome: .rejected, batch: batch)
                continue
            }
            schedule(timeout) { [weak self] in
                guard let self, self.generation == batch, self.outstanding.contains(target.stableID) else { return }
                self.update(target.stableID, outcome: .pending)
                self.publish()
            }
            refresh { [weak self] refreshed in
                guard let self, self.generation == batch, self.outstanding.contains(target.stableID) else { return }
                switch refreshed {
                case .failure(let error):
                    self.complete(target.stableID, outcome: .failed(error.localizedDescription), batch: batch)
                case .success(let inventory):
                    let matches = inventory.filter { $0.stableID == target.stableID }
                    guard !matches.isEmpty else {
                        self.complete(target.stableID, outcome: .unavailable, batch: batch)
                        return
                    }
                    guard matches.count == 1, let current = matches.first, current.selectable,
                          current.bsdName == target.bsdName, current.kind == target.kind else {
                        self.complete(target.stableID, outcome: .rejected, batch: batch)
                        return
                    }
                    self.perform(current) { [weak self] outcome in
                        self?.complete(target.stableID, outcome: outcome, batch: batch)
                    }
                }
            }
        }
        return true
    }

    private func complete(_ id: String, outcome: EjectionOutcome, batch: UUID) {
        guard generation == batch, outstanding.contains(id) else { return }
        switch outcome {
        case .working, .pending: break
        default: outstanding.remove(id)
        }
        update(id, outcome: outcome)
        isRunning = !outstanding.isEmpty
        publish()
    }

    private func update(_ id: String, outcome: EjectionOutcome) {
        guard let index = results.firstIndex(where: { $0.targetID == id }) else { return }
        results[index].outcome = outcome
    }

    private func publish() {
        state = isRunning ? .running(results) : .finished(results)
        onUpdate?(state)
    }
}
