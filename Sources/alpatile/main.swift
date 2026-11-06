import Foundation
import AlpatileCore

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    print("""
    alpatile: lightweight low-flicker tiling window manager for macOS

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
    """)
    exit(1)
}

let parseResult = Command.parse(args)
switch parseResult {
case .failure(let err):
    FileHandle.standardError.write(Data((err.message + "\n").utf8))
    exit(1)

case .success(let command):
    if case .help(let text) = command {
        print(text)
        exit(0)
    }
    let serialized = command.serialize()
    let result = SocketProtocol.sendClientCommand(serialized)
    if !result.message.isEmpty {
        print(result.message)
    }
    exit(result.success ? 0 : 1)
}
