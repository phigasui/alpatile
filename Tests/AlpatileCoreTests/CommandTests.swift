import Testing
@testable import AlpatileCore

struct CommandTests {
    @Test func parseWindowWarp() {
        #expect(Command.parse(["window", "--warp", "west"]) == .success(.windowWarp(.west)))
        #expect(Command.parse(["window", "--warp", "south"]) == .success(.windowWarp(.south)))
        #expect(Command.parse(["window", "--warp", "north"]) == .success(.windowWarp(.north)))
        #expect(Command.parse(["window", "--warp", "east"]) == .success(.windowWarp(.east)))
    }

    @Test func parseWindowToggle() {
        #expect(Command.parse(["window", "--toggle", "split"]) == .success(.windowToggleSplit))
    }

    @Test func parseWindowMaximize() {
        #expect(Command.parse(["window", "--maximize"]) == .success(.windowMaximize))
    }

    @Test func parseSpaceRotate() {
        #expect(Command.parse(["space", "--rotate", "90"]) == .success(.spaceRotate(90)))
        #expect(Command.parse(["space", "--rotate", "270"]) == .success(.spaceRotate(270)))
    }

    @Test func parseSpaceBalance() {
        #expect(Command.parse(["space", "--balance"]) == .success(.spaceBalance))
    }

    @Test func parseSpaceLayout() {
        #expect(Command.parse(["space", "--layout", "bsp"]) == .success(.spaceLayout(.bsp)))
        #expect(Command.parse(["space", "--layout", "float"]) == .success(.spaceLayout(.float)))
    }

    @Test func parseQueryAndSystemCommands() {
        #expect(Command.parse(["query", "windows"]) == .success(.queryWindows))
        #expect(Command.parse(["query", "status"]) == .success(.queryStatus))
        #expect(Command.parse(["reload"]) == .success(.reloadConfig))
        #expect(Command.parse(["ping"]) == .success(.ping))
    }

    @Test func parseInvalid() {
        if case .failure = Command.parse(["window", "--unknown"]) {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        if case .failure = Command.parse(["space", "--rotate", "45"]) {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        if case .success(.help) = Command.parse([]) {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        if case .success(.help) = Command.parse(["--help"]) {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func serialization() {
        #expect(Command.windowWarp(.west).serialize() == "window --warp west")
        #expect(Command.windowToggleSplit.serialize() == "window --toggle split")
        #expect(Command.windowMaximize.serialize() == "window --maximize")
        #expect(Command.spaceRotate(90).serialize() == "space --rotate 90")
        #expect(Command.spaceBalance.serialize() == "space --balance")
        #expect(Command.spaceLayout(.bsp).serialize() == "space --layout bsp")
        #expect(Command.queryWindows.serialize() == "query windows")
        #expect(Command.queryStatus.serialize() == "query status")
        #expect(Command.reloadConfig.serialize() == "reload")
        #expect(Command.ping.serialize() == "ping")
    }
}
