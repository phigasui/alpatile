import Foundation

public struct SocketProtocol {
    public static let defaultPath = "/tmp/alpatile.sock"

    public static var maxSocketPathUTF8Bytes: Int {
        MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1
    }

    public static func socketPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let custom = environment["ALPATILE_SOCKET"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return defaultPath
    }

    public static var socketPath: String {
        socketPath()
    }

    public static func validateSocketPath(_ path: String) -> String? {
        let byteCount = path.utf8.count
        guard byteCount > 0 else {
            return "Socket path must not be empty"
        }
        guard byteCount <= maxSocketPathUTF8Bytes else {
            return "Socket path is too long (\(byteCount) bytes; max \(maxSocketPathUTF8Bytes) bytes): \(path)"
        }
        return nil
    }

    public static func sendClientCommand(_ commandLine: String, path: String = socketPath) -> (success: Bool, message: String) {
        if let validationError = validateSocketPath(path) {
            return (false, validationError)
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            return (false, "Failed to create UNIX domain socket")
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(path.utf8)

        withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
            let ptr = UnsafeMutableRawPointer(sunPathPtr).assumingMemoryBound(to: UInt8.self)
            for i in 0..<pathBytes.count {
                ptr[i] = pathBytes[i]
            }
            ptr[pathBytes.count] = 0
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                connect(fd, sockAddrPtr, addrLen)
            }
        }

        guard connectRes == 0 else {
            return (false, "Could not connect to alpatiled daemon at \(path). Is it running?")
        }

        let payload = commandLine.hasSuffix("\n") ? commandLine : commandLine + "\n"
        let payloadBytes = Array(payload.utf8)
        let writeCount = payloadBytes.withUnsafeBytes { rawBuf -> Int in
            guard let base = rawBuf.baseAddress else { return 0 }
            return write(fd, base, rawBuf.count)
        }

        guard writeCount > 0 else {
            return (false, "Failed to send command to daemon")
        }

        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &buffer, buffer.count)
            if n < 0 {
                if errno == EINTR { continue }
                break
            }
            if n == 0 { break }
            responseData.append(buffer, count: n)
        }

        let response = String(data: responseData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isSuccess = response.hasPrefix("OK")
        return (isSuccess, response)
    }
}
