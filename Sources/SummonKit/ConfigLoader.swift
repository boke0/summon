import Foundation

public enum ConfigLoader {
    public static var defaultConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/summon/config.json")
    }

    public static var defaultUserPluginsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/summon/plugins")
    }

    /// Loads config from `url`. Missing or invalid files fall back to `AppConfig.default`.
    public static func load(from url: URL = defaultConfigURL) -> AppConfig {
        guard let data = try? Data(contentsOf: url) else {
            return .default
        }
        return (try? AppConfigJSON.decode(from: data)) ?? .default
    }
}
