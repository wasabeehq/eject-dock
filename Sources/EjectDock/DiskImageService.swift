import Foundation
import Darwin

/// Structured image inventory. Detach is owned by the native ejection adapter.
struct DiskImageService {
    func snapshot() throws -> [String: Any] {
        try InventoryCommand.plist(executable: "/usr/bin/hdiutil", arguments: ["info", "-plist"])
    }
}

enum InventoryCommand {
    enum Failure: Error { case commandFailed, malformedPropertyList, timedOut }

    /// Called only on the inventory worker queue. stdout is drained while the process runs.
    static func plist(executable: String, arguments: [String]) throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15, execute: deadline)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()
        guard process.terminationStatus == 0 else { throw Failure.commandFailed }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw Failure.malformedPropertyList
        }
        return plist
    }
}
