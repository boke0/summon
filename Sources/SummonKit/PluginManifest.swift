import Foundation

public struct PluginManifest: Codable, Equatable, Sendable {
    public var name: String
    public var title: String
    public var search: [String]
    public var action: [String]

    public init(name: String, title: String, search: [String], action: [String]) {
        self.name = name
        self.title = title
        self.search = search
        self.action = action
    }
}

public enum PluginManifestJSON {
    public static func decode(from data: Data) throws -> PluginManifest {
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
        try validate(manifest)
        return manifest
    }

    public static func validate(_ manifest: PluginManifest) throws {
        guard !manifest.name.isEmpty else {
            throw PluginContractError.emptyField("name")
        }
        guard !manifest.title.isEmpty else {
            throw PluginContractError.emptyField("title")
        }
        guard !manifest.search.isEmpty else {
            throw PluginContractError.emptyCommand("search")
        }
        guard !manifest.action.isEmpty else {
            throw PluginContractError.emptyCommand("action")
        }
    }
}

public enum PluginContractError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyCommand(String)
}
