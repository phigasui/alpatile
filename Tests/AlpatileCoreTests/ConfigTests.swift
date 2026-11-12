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

    @Test func codableCamelCase() throws {
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

    @Test func decodeSnakeCaseAndShorthand() throws {
        let json = """
        {
            "padding": 12,
            "gap": 6,
            "ignore_apps": [
                "CustomIgnoreApp"
            ]
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Config.self, from: data)

        #expect(decoded.topPadding == 12)
        #expect(decoded.bottomPadding == 12)
        #expect(decoded.leftPadding == 12)
        #expect(decoded.rightPadding == 12)
        #expect(decoded.windowGap == 6)
        #expect(decoded.shouldIgnore(appName: "CustomIgnoreApp"))
        #expect(!decoded.shouldIgnore(appName: "OtherApp"))
    }

    @Test func defaultConfigURLRespectsAndFallsBackFromHomeEnvironment() {
        let fallback = URL(fileURLWithPath: "/Users/fallback", isDirectory: true)

        let withHome = Config.defaultConfigURL(
            environment: ["HOME": "/Users/custom"],
            fallbackHome: fallback
        )
        #expect(withHome.path == "/Users/custom/.config/alpatile/config.json")

        let missingHome = Config.defaultConfigURL(
            environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
            fallbackHome: fallback
        )
        #expect(missingHome.path == "/Users/fallback/.config/alpatile/config.json")

        let blankHome = Config.defaultConfigURL(
            environment: ["HOME": "   "],
            fallbackHome: fallback
        )
        #expect(blankHome.path == "/Users/fallback/.config/alpatile/config.json")
    }

    @Test func loadMissingOrInvalidConfigFallsBackToDefault() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("alpatile-config-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let missingURL = dir.appendingPathComponent("missing.json")
        #expect(Config.load(from: missingURL) == .default)

        let invalidURL = dir.appendingPathComponent("invalid.json")
        try Data("{not valid json".utf8).write(to: invalidURL)
        #expect(Config.load(from: invalidURL) == .default)
    }
}
