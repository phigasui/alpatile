import Foundation

public struct Config: Sendable, Codable, Equatable {
    public var topPadding: CGFloat
    public var bottomPadding: CGFloat
    public var leftPadding: CGFloat
    public var rightPadding: CGFloat
    public var windowGap: CGFloat
    public var ignoreApps: [String]

    public init(
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0,
        leftPadding: CGFloat = 0,
        rightPadding: CGFloat = 0,
        windowGap: CGFloat = 0,
        ignoreApps: [String] = ["DeepL", "System Settings", "システム環境設定", "Finder"]
    ) {
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.leftPadding = leftPadding
        self.rightPadding = rightPadding
        self.windowGap = windowGap
        self.ignoreApps = ignoreApps
    }

    public static let `default` = Config()

    public static func defaultConfigURL() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/alpatile/config.json")
    }

    public static func load(from url: URL = defaultConfigURL()) -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(Config.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(to url: URL = defaultConfigURL()) throws {
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    public func shouldIgnore(appName: String) -> Bool {
        ignoreApps.contains { ignore in
            appName.localizedCaseInsensitiveContains(ignore) || ignore.localizedCaseInsensitiveContains(appName)
        }
    }
}
