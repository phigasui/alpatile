import Foundation
import Testing
@testable import AlpatileCore

struct ConfigTests {
    @Test func defaultConfig() {
        let config = Config.default
        #expect(config.topPadding == 0)
        #expect(config.bottomPadding == 0)
        #expect(config.leftPadding == 0)
        #expect(config.rightPadding == 0)
        #expect(config.windowGap == 0)
        #expect(config.shouldIgnore(appName: "DeepL"))
        #expect(config.shouldIgnore(appName: "System Settings"))
        #expect(config.shouldIgnore(appName: "システム環境設定"))
        #expect(!config.shouldIgnore(appName: "Google Chrome"))
    }

    @Test func codable() throws {
        let original = Config(
            topPadding: 10,
            bottomPadding: 10,
            leftPadding: 5,
            rightPadding: 5,
            windowGap: 8,
            ignoreApps: ["TestApp"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Config.self, from: data)

        #expect(original == decoded)
    }
}
