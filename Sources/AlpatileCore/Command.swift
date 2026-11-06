import Foundation

public struct CommandError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

public enum Command: Sendable, Equatable {
    case windowWarp(Direction)
    case windowToggleSplit
    case windowMaximize
    case spaceRotate(Int)
    case spaceBalance
    case spaceLayout(LayoutMode)
    case queryWindows
    case queryStatus
    case reloadConfig
    case ping
    case help(String)

    public static func parse(_ args: [String]) -> Result<Command, CommandError> {
        guard !args.isEmpty else {
            return .success(.help(helpText))
        }

        switch args[0] {
        case "window":
            guard args.count >= 2 else {
                return .failure(CommandError("Missing window subcommand: --warp, --toggle, --maximize"))
            }
            switch args[1] {
            case "--warp":
                guard args.count >= 3, let direction = Direction(rawValue: args[2].lowercased()) else {
                    return .failure(CommandError("Usage: alpatile window --warp <west|south|north|east>"))
                }
                return .success(.windowWarp(direction))
            case "--toggle":
                guard args.count >= 3, args[2] == "split" else {
                    return .failure(CommandError("Usage: alpatile window --toggle split"))
                }
                return .success(.windowToggleSplit)
            case "--maximize":
                return .success(.windowMaximize)
            default:
                return .failure(CommandError("Unknown window option: \(args[1])"))
            }

        case "space":
            guard args.count >= 2 else {
                return .failure(CommandError("Missing space subcommand: --rotate, --balance, --layout"))
            }
            switch args[1] {
            case "--rotate":
                guard args.count >= 3, let deg = Int(args[2]), deg == 90 || deg == 270 else {
                    return .failure(CommandError("Usage: alpatile space --rotate 90"))
                }
                return .success(.spaceRotate(deg))
            case "--balance":
                return .success(.spaceBalance)
            case "--layout":
                guard args.count >= 3, let mode = LayoutMode(rawValue: args[2].lowercased()) else {
                    return .failure(CommandError("Usage: alpatile space --layout <bsp|float>"))
                }
                return .success(.spaceLayout(mode))
            default:
                return .failure(CommandError("Unknown space option: \(args[1])"))
            }

        case "query":
            if args.count >= 2 && args[1] == "windows" {
                return .success(.queryWindows)
            }
            return .success(.queryStatus)

        case "reload":
            return .success(.reloadConfig)

        case "ping":
            return .success(.ping)

        case "help", "--help", "-h":
            return .success(.help(helpText))

        default:
            return .failure(CommandError("Unknown command: \(args[0]). Run 'alpatile help' for usage."))
        }
    }

    public static let helpText = """
    alpatile - Lightweight, low-flicker tiling window manager for macOS

    Usage:
      alpatile window --warp <west|south|north|east>
      alpatile window --toggle split
      alpatile window --maximize
      alpatile space --rotate 90
      alpatile space --balance
      alpatile space --layout <bsp|float>
      alpatile query [windows|status]
      alpatile reload
      alpatile ping
    """

    public func serialize() -> String {
        switch self {
        case .windowWarp(let dir):
            return "window --warp \(dir.rawValue)"
        case .windowToggleSplit:
            return "window --toggle split"
        case .windowMaximize:
            return "window --maximize"
        case .spaceRotate(let deg):
            return "space --rotate \(deg)"
        case .spaceBalance:
            return "space --balance"
        case .spaceLayout(let mode):
            return "space --layout \(mode.rawValue)"
        case .queryWindows:
            return "query windows"
        case .queryStatus:
            return "query status"
        case .reloadConfig:
            return "reload"
        case .ping:
            return "ping"
        case .help:
            return "help"
        }
    }
}
