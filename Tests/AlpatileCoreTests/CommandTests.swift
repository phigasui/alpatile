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
    }

    @Test func parseSpaceBalance() {
        #expect(Command.parse(["space", "--balance"]) == .success(.spaceBalance))
    }

    @Test func parseSpaceLayout() {
        #expect(Command.parse(["space", "--layout", "bsp"]) == .success(.spaceLayout(.bsp)))
        #expect(Command.parse(["space", "--layout", "float"]) == .success(.spaceLayout(.float)))
    }

    @Test func parseInvalid() {
        if case .failure = Command.parse(["window", "--unknown"]) {
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
    }
}
