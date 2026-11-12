import Foundation
import Darwin
import Testing
@testable import AlpatileCore

struct DaemonLockTests {
    private func makeTempDir() throws -> URL {
        // Keep path well under macOS sockaddr_un.sun_path limit (103 bytes); NSTemporaryDirectory is ~50+ bytes.
        let shortID = String(UUID().uuidString.prefix(8))
        let dir = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("at-test-\(shortID)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func defaultLockPathAppendsLockSuffix() {
        #expect(DaemonLock.defaultLockPath(for: "/tmp/custom.sock") == "/tmp/custom.sock.lock")
    }

    @Test func acquireWritesPIDAndReleaseCleansUpOwnedSocket() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let socketPath = dir.appendingPathComponent("test.sock").path
        let lock = try DaemonLock.acquire(socketPath: socketPath)
        #expect(lock.isHeld)
        #expect(lock.lockPath == "\(socketPath).lock")

        let pidText = try String(contentsOfFile: lock.lockPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(Int32(pidText) == getpid())

        FileManager.default.createFile(atPath: socketPath, contents: Data("sock".utf8))
        lock.markSocketOwned()
        lock.release(removeSocket: true)

        #expect(!lock.isHeld)
        #expect(!FileManager.default.fileExists(atPath: socketPath))
        // Lock file intentionally stays on disk to avoid flock inode races.
        #expect(FileManager.default.fileExists(atPath: lock.lockPath))
    }

    @Test func secondAcquireFailsWithoutModifyingExistingSocket() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let socketPath = dir.appendingPathComponent("live.sock").path
        let markerData = Data("active-daemon-socket".utf8)
        let lock1 = try DaemonLock.acquire(socketPath: socketPath)
        defer { lock1.release(removeSocket: true) }

        FileManager.default.createFile(atPath: socketPath, contents: markerData)
        lock1.markSocketOwned()

        do {
            _ = try DaemonLock.acquire(socketPath: socketPath)
            Issue.record("Expected second DaemonLock.acquire to fail while lock1 is held")
        } catch let error as DaemonLockError {
            #expect(error == .alreadyLocked(lockPath: "\(socketPath).lock", ownerPID: getpid()))
        }

        let remaining = try Data(contentsOf: URL(fileURLWithPath: socketPath))
        #expect(remaining == markerData)
        #expect(lock1.isHeld)
    }

    @Test func reacquireSucceedsAfterRelease() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let socketPath = dir.appendingPathComponent("reacquire.sock").path
        let lock1 = try DaemonLock.acquire(socketPath: socketPath)
        lock1.release(removeSocket: false)
        #expect(!lock1.isHeld)

        let lock2 = try DaemonLock.acquire(socketPath: socketPath)
        defer { lock2.release(removeSocket: true) }
        #expect(lock2.isHeld)
    }

    @Test func releaseWithoutSocketOwnershipPreservesSocket() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let socketPath = dir.appendingPathComponent("unowned.sock").path
        FileManager.default.createFile(atPath: socketPath, contents: Data("keep".utf8))

        let lock = try DaemonLock.acquire(socketPath: socketPath)
        lock.release(removeSocket: true)

        #expect(FileManager.default.fileExists(atPath: socketPath))
    }

    @Test func removeStaleSocketRemovesExistingFileWhileLockHeld() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let socketPath = dir.appendingPathComponent("stale.sock").path
        FileManager.default.createFile(atPath: socketPath, contents: Data())

        let lock = try DaemonLock.acquire(socketPath: socketPath)
        defer { lock.release(removeSocket: true) }

        lock.removeStaleSocket()
        #expect(!FileManager.default.fileExists(atPath: socketPath))
    }

    @Test func invalidSocketPathRejected() throws {
        #expect(throws: DaemonLockError.invalidSocketPath("Socket path must not be empty")) {
            _ = try DaemonLock.acquire(socketPath: "")
        }

        let tooLongPath = "/" + String(repeating: "a", count: SocketProtocol.maxSocketPathUTF8Bytes)
        do {
            _ = try DaemonLock.acquire(socketPath: tooLongPath)
            Issue.record("Expected overlong socket path to throw")
        } catch let error as DaemonLockError {
            if case .invalidSocketPath = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func socketProtocolEnvironmentResolutionAndValidation() {
        #expect(SocketProtocol.socketPath(environment: [:]) == SocketProtocol.defaultPath)
        #expect(SocketProtocol.socketPath(environment: ["ALPATILE_SOCKET": ""]) == SocketProtocol.defaultPath)
        #expect(SocketProtocol.socketPath(environment: ["ALPATILE_SOCKET": "   \n"]) == SocketProtocol.defaultPath)
        #expect(
            SocketProtocol.socketPath(environment: ["ALPATILE_SOCKET": "/tmp/custom-alpatile.sock"])
                == "/tmp/custom-alpatile.sock"
        )

        let maxValid = "/" + String(repeating: "a", count: SocketProtocol.maxSocketPathUTF8Bytes - 1)
        #expect(SocketProtocol.validateSocketPath(maxValid) == nil)

        let overMax = "/" + String(repeating: "a", count: SocketProtocol.maxSocketPathUTF8Bytes)
        #expect(SocketProtocol.validateSocketPath(overMax) != nil)
    }
}
