import Foundation
import Darwin
@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import AlpatileCore

private final class ActiveLockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: DaemonLock?

    func set(_ newValue: DaemonLock?) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func take() -> DaemonLock? {
        lock.lock()
        let current = value
        value = nil
        lock.unlock()
        return current
    }
}

private func writeStderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

// Disable stdio buffering so launchd log files receive output immediately.
setbuf(stdout, nil)
setbuf(stderr, nil)

// Avoid crashing on broken client pipes.
signal(SIGPIPE, SIG_IGN)

private let activeLockBox = ActiveLockBox()
let socketPath = SocketProtocol.socketPath

// 1. Acquire exclusive daemon lock before touching any existing socket file.
let daemonLock: DaemonLock
do {
    daemonLock = try DaemonLock.acquire(socketPath: socketPath)
} catch {
    writeStderr("[alpatiled] ERROR: \(error.localizedDescription). Existing socket at \(socketPath) was not modified.")
    exit(1)
}

// 2. Check Accessibility permissions
if !AccessibilityHelper.checkAccessibilityPermissions(prompt: false) {
    writeStderr("[alpatiled] WARNING: Accessibility permissions are not granted. Please allow alpatiled in System Settings > Privacy & Security > Accessibility.")
}

// Safe to remove any stale socket left by a previous crashed daemon now that we hold the lock.
daemonLock.removeStaleSocket()

// 3. Initialize Engine
let engine = WindowEngine()

// 4. Setup UNIX domain socket server
let serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
guard serverFd >= 0 else {
    let err = errno
    daemonLock.release(removeSocket: false)
    writeStderr("[alpatiled] ERROR: Failed to create UNIX domain socket: \(String(cString: strerror(err)))")
    exit(1)
}

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = Array(socketPath.utf8)
guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
    close(serverFd)
    daemonLock.release(removeSocket: false)
    writeStderr("[alpatiled] ERROR: Socket path is too long: \(socketPath)")
    exit(1)
}
withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
    let ptr = UnsafeMutableRawPointer(sunPathPtr).assumingMemoryBound(to: UInt8.self)
    for i in 0..<pathBytes.count {
        ptr[i] = pathBytes[i]
    }
    ptr[pathBytes.count] = 0
}

let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
let bindRes = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
        bind(serverFd, sockAddrPtr, addrLen)
    }
}

guard bindRes == 0 else {
    let err = errno
    close(serverFd)
    daemonLock.release(removeSocket: false)
    writeStderr("[alpatiled] ERROR: Failed to bind socket at \(socketPath): \(String(cString: strerror(err)))")
    exit(1)
}

// Only clean up the socket on exit once this process has bound it.
daemonLock.markSocketOwned()
activeLockBox.set(daemonLock)

atexit {
    activeLockBox.take()?.release(removeSocket: true)
}

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigIntSource.setEventHandler {
    activeLockBox.take()?.release(removeSocket: true)
    exit(0)
}
sigIntSource.resume()

let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigTermSource.setEventHandler {
    activeLockBox.take()?.release(removeSocket: true)
    exit(0)
}
sigTermSource.resume()

guard listen(serverFd, 16) == 0 else {
    let err = errno
    close(serverFd)
    activeLockBox.take()?.release(removeSocket: true)
    writeStderr("[alpatiled] ERROR: Failed to listen on socket at \(socketPath): \(String(cString: strerror(err)))")
    exit(1)
}

print("[alpatiled] Daemon running. Listening on \(socketPath)")

// 4. Background task for socket connections
Task.detached {
    while true {
        var clientAddr = sockaddr_un()
        var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                accept(serverFd, sockAddrPtr, &clientLen)
            }
        }

        guard clientFd >= 0 else { continue }

        Task {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(clientFd, &buffer, buffer.count)
            if bytesRead > 0 {
                let rawInput = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
                let commandLine = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let args = commandLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                let response: String
                switch Command.parse(args) {
                case .failure(let err):
                    response = "ERROR: \(err)\n"
                case .success(let cmd):
                    let output = await engine.execute(command: cmd)
                    response = output.hasSuffix("\n") ? output : output + "\n"
                }

                _ = response.utf8.withContiguousStorageIfAvailable { strBuf in
                    write(clientFd, strBuf.baseAddress, strBuf.count)
                }
            }
            close(clientFd)
        }
    }
}

// 5. Watch for workspace events (app activate, etc.)
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil,
    queue: .main
) { _ in
    Task {
        await engine.scanAndSyncWindows()
    }
}

// Space switches and display changes don't activate an app, so sync on them explicitly.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.activeSpaceDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    Task {
        await engine.scanAndSyncWindows()
    }
}

NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil,
    queue: .main
) { _ in
    Task {
        await engine.scanAndSyncWindows()
    }
}

// Initial window scan
Task {
    await engine.scanAndSyncWindows()
}

// Run loop
CFRunLoopRun()
