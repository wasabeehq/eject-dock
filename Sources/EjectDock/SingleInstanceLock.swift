import Foundation
import Darwin

/// The kernel releases the lock even if the application crashes. This prevents
/// a second application process from bypassing the in-process operation lock.
final class SingleInstanceLock {
    enum Failure: Error { case alreadyRunning, unavailable }
    private let descriptor: Int32

    init() throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("EjectDock", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("instance.lock").path
        let fd = Darwin.open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw Failure.unavailable }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(fd)
            throw code == EWOULDBLOCK ? Failure.alreadyRunning : Failure.unavailable
        }
        descriptor = fd
    }

    deinit { close(descriptor) }
}
