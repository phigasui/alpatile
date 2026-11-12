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

    private enum CodingKeys: String, CodingKey {
        case topPadding = "topPadding"
        case topPaddingSnake = "top_padding"
        case bottomPadding = "bottomPadding"
        case bottomPaddingSnake = "bottom_padding"
        case leftPadding = "leftPadding"
        case leftPaddingSnake = "left_padding"
        case rightPadding = "rightPadding"
        case rightPaddingSnake = "right_padding"
        case windowGap = "windowGap"
        case windowGapSnake = "window_gap"
        case gap = "gap"
        case padding = "padding"
        case ignoreApps = "ignoreApps"
        case ignoreAppsSnake = "ignore_apps"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let uniformPadding = try container.decodeIfPresent(CGFloat.self, forKey: .padding) ?? 0

        self.topPadding = try container.decodeIfPresent(CGFloat.self, forKey: .topPadding)
            ?? container.decodeIfPresent(CGFloat.self, forKey: .topPaddingSnake)
            ?? uniformPadding

        self.bottomPadding = try container.decodeIfPresent(CGFloat.self, forKey: .bottomPadding)
            ?? container.decodeIfPresent(CGFloat.self, forKey: .bottomPaddingSnake)
            ?? uniformPadding

        self.leftPadding = try container.decodeIfPresent(CGFloat.self, forKey: .leftPadding)
            ?? container.decodeIfPresent(CGFloat.self, forKey: .leftPaddingSnake)
            ?? uniformPadding

        self.rightPadding = try container.decodeIfPresent(CGFloat.self, forKey: .rightPadding)
            ?? container.decodeIfPresent(CGFloat.self, forKey: .rightPaddingSnake)
            ?? uniformPadding

        self.windowGap = try container.decodeIfPresent(CGFloat.self, forKey: .windowGap)
            ?? container.decodeIfPresent(CGFloat.self, forKey: .windowGapSnake)
            ?? container.decodeIfPresent(CGFloat.self, forKey: .gap)
            ?? 0

        self.ignoreApps = try container.decodeIfPresent([String].self, forKey: .ignoreApps)
            ?? container.decodeIfPresent([String].self, forKey: .ignoreAppsSnake)
            ?? ["DeepL", "System Settings", "システム環境設定", "Finder"]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topPadding, forKey: .topPadding)
        try container.encode(bottomPadding, forKey: .bottomPadding)
        try container.encode(leftPadding, forKey: .leftPadding)
        try container.encode(rightPadding, forKey: .rightPadding)
        try container.encode(windowGap, forKey: .windowGap)
        try container.encode(ignoreApps, forKey: .ignoreApps)
    }

    public static let `default` = Config()

    public static func defaultConfigURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallbackHome: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let homeDir: URL
        if let envHome = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envHome.isEmpty {
            homeDir = URL(fileURLWithPath: envHome, isDirectory: true)
        } else {
            homeDir = fallbackHome
        }
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
            let msg = "[alpatile] Warning: Failed to parse config at \(url.path): \(error). Using default config.\n"
            FileHandle.standardError.write(Data(msg.utf8))
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
