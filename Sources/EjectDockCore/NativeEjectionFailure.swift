import Foundation

public struct NativeEjectionFailure: Equatable {
    public enum Stage: String { case volumeUnmount, wholeUnmount, eject }
    public let stage: Stage
    public let code: UInt32
    public let unmountedVolumes: Int
    public let requestedVolumes: Int
    public let wholeUnmountSucceeded: Bool
    public let detail: String?

    public init(stage: Stage, code: UInt32, unmountedVolumes: Int,
                requestedVolumes: Int, wholeUnmountSucceeded: Bool, detail: String?) {
        self.stage = stage
        self.code = code
        self.unmountedVolumes = unmountedVolumes
        self.requestedVolumes = requestedVolumes
        self.wholeUnmountSucceeded = wholeUnmountSucceeded
        self.detail = detail
    }

    public var hasUnmountedVolumes: Bool { unmountedVolumes > 0 || wholeUnmountSucceeded }
    // Disk Arbitration may return its own busy status or Mach-encoded BSD EBUSY.
    public var isBusy: Bool { code == 0xF8DA0002 || code == 0x0000C010 }
}
