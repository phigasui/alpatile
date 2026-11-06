import Foundation
@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import AlpatileCore

// Ensure socket is cleaned up on exit
let socketPath = SocketProtocol.socketPath

func cleanup() {
    unlink(socketPath)
}

signal(SIGINT) { _ in
    cleanup()
    exit(0)
}
signal(SIGTERM) { _ in
    cleanup()
    exit(0)
}
atexit {
    cleanup()
}

// 1. Check Accessibility permissions
if !AccessibilityHelper.checkAccessibilityPermissions(prompt: false) {
    FileHandle.standardError.write(Data("[alpatiled] WARNING: Accessibility permissions are not granted. Please allow alpatiled in System Settings > Privacy & Security > Accessibility.\n".utf8))
}

cleanup()

// 2. Initialize Engine
let engine = WindowEngine()

// 3. Setup UNIX domain socket server
let serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
guard serverFd >= 0 else {
    fatalError("Failed to create UNIX domain socket")
}

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = Array(socketPath.utf8)
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
    fatalError("Failed to bind socket at \(socketPath)")
}

guard listen(serverFd, 16) == 0 else {
    fatalError("Failed to listen on socket")
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
NotificationCenter.default.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
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
