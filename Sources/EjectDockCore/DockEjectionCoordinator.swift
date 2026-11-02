import Foundation

public final class DockEjectionCoordinator {
    public typealias Refresh = (@escaping (Result<InventorySnapshot, Error>) -> Void) -> Void
    public typealias Perform = (InventoryTarget, @escaping (EjectionOutcome) -> Void) -> Void
    public typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void

    private let refresh: Refresh
    private let perform: Perform
    private let schedule: Schedule
    private let timeout: TimeInterval
    private var generation = UUID()
    private var requested: DockTarget?
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
    public func eject(_ dock: DockTarget) -> Bool {
        guard !isRunning else { return false }
        requested = dock
        generation = UUID()
        let batch = generation
        isRunning = true
        publish(.working)
        guard dock.selectable else {
            finish(.rejected, batch: batch)
            return true
        }
        schedule(timeout) { [weak self] in
            guard let self, self.generation == batch, self.isRunning else { return }
            self.publish(.pending)
        }
        continueOperation(batch: batch)
        return true
    }

    private func continueOperation(batch: UUID) {
        refresh { [weak self] result in
            guard let self, self.generation == batch, self.isRunning, let dock = self.requested else { return }
            switch result {
            case .failure(let error):
                self.finish(.failed(error.localizedDescription), batch: batch)
            case .success(let snapshot):
                let matches = snapshot.docks.filter { $0.stableID == dock.stableID }
                guard !matches.isEmpty else {
                    self.finish(.unavailable, batch: batch)
                    return
                }
                guard matches.count == 1, let currentDock = matches.first, currentDock.selectable,
                      currentDock.persistence == dock.persistence,
                      let members = DockTopology.members(of: dock, in: snapshot) else {
                    self.finish(.rejected, batch: batch)
                    return
                }
                if let mounted = members.first(where: {
                    $0.hasMountedSnapshots || $0.volumes.contains { $0.mountPath != nil }
                }) {
                    self.perform(mounted) { [weak self] outcome in
                        guard let self, self.generation == batch, self.isRunning else { return }
                        if outcome == .success {
                            self.continueOperation(batch: batch)
                        } else {
                            self.finish(outcome, batch: batch)
                        }
                    }
                    return
                }
                switch DockTopology.readiness(of: currentDock, in: snapshot) {
                case .ready: self.finish(.success, batch: batch)
                case .unavailable: self.finish(.unavailable, batch: batch)
                case .blocked(let names): self.finish(.dockReadinessBlocked(names), batch: batch)
                }
            }
        }
    }

    private func finish(_ outcome: EjectionOutcome, batch: UUID) {
        guard generation == batch, isRunning else { return }
        isRunning = false
        publish(outcome)
    }

    private func publish(_ outcome: EjectionOutcome) {
        guard let dock = requested else { return }
        let result = EjectionResult(targetID: dock.stableID, name: dock.name, outcome: outcome)
        state = isRunning ? .running([result]) : .finished([result])
        onUpdate?(state)
    }
}
