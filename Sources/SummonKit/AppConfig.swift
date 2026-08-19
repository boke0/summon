import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var hotkey: String
    public var tabModifier: String
    public var tabs: [String]

    public static let `default` = AppConfig(
        hotkey: "cmd+d",
        tabModifier: "cmd",
        tabs: ["apps", "cursor"]
    )

    public init(
        hotkey: String = AppConfig.default.hotkey,
        tabModifier: String = AppConfig.default.tabModifier,
        tabs: [String] = AppConfig.default.tabs
    ) {
        self.hotkey = hotkey
        self.tabModifier = tabModifier
        self.tabs = tabs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? Self.default.hotkey
        tabModifier = try container.decodeIfPresent(String.self, forKey: .tabModifier)
            ?? Self.default.tabModifier
        tabs = try container.decodeIfPresent([String].self, forKey: .tabs) ?? Self.default.tabs
    }
}

public enum AppConfigJSON {
    public static func decode(from data: Data) throws -> AppConfig {
        try JSONDecoder().decode(AppConfig.self, from: data)
    }
}
