import Foundation
import Darwin

public enum DaemonLockError: Error, LocalizedError, Equatable {
    case invalidSocketPath(String)
    case openFailed(lockPath: String, errno: Int32)
    case alreadyLocked(lockPath: String, ownerPID: Int32?)
    case lockFailed(lockPath: String, errno: Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidSocketPath(let reason):
            return reason
        case .openFailed(let lockPath, let err):
            return "Failed to open lock file at \(lockPath): \(String(cString: strerror(err))) (errno=\(err))"
        case .alreadyLocked(let lockPath, let ownerPID):
            if let ownerPID {
                return "Another alpatiled instance is already running (PID \(ownerPID), lock: \(lockPath))"
            }
            return "Another alpatiled instance is already running (lock: \(lockPath))"
        case .lockFailed(let lockPath, let err):
            return "Failed to acquire lock at \(lockPath): \(String(cString: strerror(err))) (errno=\(err))"
        }
    }
}

/// Exclusive `flock`-based lock guarding ownership of the daemon UNIX domain socket.
public final class DaemonLock: @unchecked Sendable {
    public let socketPath: String
    public let lockPath: String

    private let stateLock = NSLock()
    private var fd: Int32
    private var ownsSocket: Bool = false

    public static func defaultLockPath(for socketPath: String) -> String {
        "\(socketPath).lock"
    }

    private init(socketPath: String, lockPath: String, fd: Int32) {
        self.socketPath = socketPath
        self.lockPath = lockPath
        self.fd = fd
    }

    deinit {
        stateLock.lock()
        let currentFd = fd
        fd = -1
        ownsSocket = false
        stateLock.unlock()

        if currentFd >= 0 {
            close(currentFd)
        }
    }

    public var isHeld: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return fd >= 0
    }

    public static func acquire(socketPath: String, lockPath: String? = nil) throws -> DaemonLock {
        if let validationError = SocketProtocol.validateSocketPath(socketPath) {
            throw DaemonLockError.invalidSocketPath(validationError)
        }

        let resolvedLockPath = lockPath ?? defaultLockPath(for: socketPath)
        let fd = open(resolvedLockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard fd >= 0 else {
            throw DaemonLockError.openFailed(lockPath: resolvedLockPath, errno: errno)
        }

        var flockResult: Int32 = -1
        var flockErrno: Int32 = 0
        repeat {
            flockResult = flock(fd, LOCK_EX | LOCK_NB)
            flockErrno = errno
        } while flockResult == -1 && flockErrno == EINTR

        guard flockResult == 0 else {
            let ownerPID: Int32? = (flockErrno == EWOULDBLOCK || flockErrno == EAGAIN) ? readPID(from: fd) : nil
            close(fd)
            if flockErrno == EWOULDBLOCK || flockErrno == EAGAIN {
                throw DaemonLockError.alreadyLocked(lockPath: resolvedLockPath, ownerPID: ownerPID)
            }
            throw DaemonLockError.lockFailed(lockPath: resolvedLockPath, errno: flockErrno)
        }

        writePID(getpid(), to: fd)
        return DaemonLock(socketPath: socketPath, lockPath: resolvedLockPath, fd: fd)
    }

    /// Removes any leftover socket file from a previously crashed process while holding the lock.
    public func removeStaleSocket() {
        stateLock.lock()
        let active = fd >= 0
        stateLock.unlock()
        guard active else { return }
        unlink(socketPath)
    }

    /// Marks this lock holder as the owner of the bound socket file so `release` unlinks it on exit.
    public func markSocketOwned() {
        stateLock.lock()
        if fd >= 0 {
            ownsSocket = true
        }
        stateLock.unlock()
    }

    /// Releases the lock and unlinks the socket if owned. Safe to call multiple times.
    /// The socket is unlinked BEFORE closing `fd` so no new instance can bind between unlock and unlink.
    public func release(removeSocket: Bool = true) {
        stateLock.lock()
        let currentFd = fd
        let shouldUnlink = removeSocket && ownsSocket
        fd = -1
        ownsSocket = false
        stateLock.unlock()

        guard currentFd >= 0 else { return }
        if shouldUnlink {
            unlink(socketPath)
        }
        // Keep the lock file on disk; unlinking a flock-guarded file creates inode races.
        close(currentFd)
    }

    private static func readPID(from fd: Int32) -> Int32? {
        var buffer = [UInt8](repeating: 0, count: 32)
        let bytesRead = pread(fd, &buffer, buffer.count, 0)
        guard bytesRead > 0 else { return nil }
        let raw = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int32(raw)
    }

    private static func writePID(_ pid: pid_t, to fd: Int32) {
        _ = ftruncate(fd, 0)
        _ = lseek(fd, 0, SEEK_SET)
        let bytes = Array("\(pid)\n".utf8)
        bytes.withUnsafeBytes { rawBuf in
            if let base = rawBuf.baseAddress {
                _ = write(fd, base, rawBuf.count)
            }
        }
    }
}
