import Foundation
import CoreGraphics

public typealias WindowID = CGWindowID

public enum Direction: String, Sendable, Codable, CaseIterable {
    case west
    case south
    case north
    case east
}

public enum SplitType: String, Sendable, Codable {
    case horizontal // Top and Bottom
    case vertical   // Left and Right

    public var opposite: SplitType {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}

public enum LayoutMode: String, Sendable, Codable {
    case bsp
    case float
}

public struct WindowSnapshot: Sendable, Codable, Equatable {
    public let id: WindowID
    public let pid: pid_t
    public let appName: String
    public let title: String
    public var frame: CGRect

    public init(id: WindowID, pid: pid_t, appName: String, title: String, frame: CGRect) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.title = title
        self.frame = frame
    }
}
