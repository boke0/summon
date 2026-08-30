import Foundation

public enum PluginSource: String, Equatable, Sendable {
    case bundled
    case user
}

public struct LoadedPlugin: Equatable, Sendable {
    public var manifest: PluginManifest
    public var directory: URL
    public var source: PluginSource

    public init(manifest: PluginManifest, directory: URL, source: PluginSource) {
        self.manifest = manifest
        self.directory = directory
        self.source = source
    }

    public var searchExecutable: URL {
        resolve(manifest.search[0])
    }

    public var searchArguments: [String] {
        Array(manifest.search.dropFirst())
    }

    public var actionExecutable: URL {
        resolve(manifest.action[0])
    }

    public var actionArguments: [String] {
        Array(manifest.action.dropFirst())
    }

    private func resolve(_ command: String) -> URL {
        let url = URL(fileURLWithPath: command)
        if url.isFileURL, command.hasPrefix("/") {
            return url
        }
        return directory.appendingPathComponent(command)
    }
}

public enum PluginLoader {
    /// Loads plugin directories that contain a valid `plugin.json`.
    /// User plugins override bundled plugins with the same `name`.
    public static func load(bundledDirectory: URL?, userDirectory: URL?) -> [LoadedPlugin] {
        var byName: [String: LoadedPlugin] = [:]
        if let bundledDirectory {
            for plugin in scan(bundledDirectory, source: .bundled) {
                byName[plugin.manifest.name] = plugin
            }
        }
        if let userDirectory {
            for plugin in scan(userDirectory, source: .user) {
                byName[plugin.manifest.name] = plugin
            }
        }
        return Array(byName.values)
    }

    public static func scan(_ directory: URL, source: PluginSource) -> [LoadedPlugin] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { item in
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            let manifestURL = item.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? PluginManifestJSON.decode(from: data)
            else {
                return nil
            }
            return LoadedPlugin(manifest: manifest, directory: item, source: source)
        }
    }
}

public enum PluginResolver {
    /// Applies `config.tabs` as an ordered filter. If none of those names are loaded,
    /// falls back to every loaded plugin sorted by name (so a sample plugin still appears
    /// when the default tabs are not installed yet).
    public static func tabs(from loaded: [LoadedPlugin], orderedBy names: [String]) -> [LoadedPlugin] {
        let byName = Dictionary(
            loaded.map { ($0.manifest.name, $0) },
            uniquingKeysWith: { _, new in new }
        )
        let ordered = names.compactMap { byName[$0] }
        if ordered.isEmpty {
            return loaded.sorted { $0.manifest.name < $1.manifest.name }
        }
        return ordered
    }
}
