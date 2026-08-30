import Foundation
import Testing
@testable import SummonKit

@Test func decodeFullConfig() throws {
    let json = """
    {"hotkey":"ctrl+shift+space","tabModifier":"opt","tabs":["echo","apps"]}
    """
    let config = try AppConfigJSON.decode(from: Data(json.utf8))
    #expect(config.hotkey == "ctrl+shift+space")
    #expect(config.tabModifier == "opt")
    #expect(config.tabs == ["echo", "apps"])
}

@Test func decodeConfigFillsDefaults() throws {
    let config = try AppConfigJSON.decode(from: Data("{}".utf8))
    #expect(config == .default)
    #expect(config.hotkey == "cmd+d")
    #expect(config.tabModifier == "cmd")
    #expect(config.tabs == ["apps", "cursor", "regex"])
}

@Test func loadMissingFileReturnsDefault() {
    let url = URL(fileURLWithPath: "/tmp/summon-missing-config-\(UUID().uuidString).json")
    #expect(ConfigLoader.load(from: url) == .default)
}

@Test func loadInvalidFileReturnsDefault() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-invalid-\(UUID().uuidString).json")
    try Data("not json".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(ConfigLoader.load(from: url) == .default)
}

@Test func loadValidFile() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-valid-\(UUID().uuidString).json")
    try Data(#"{"hotkey":"cmd+j","tabs":["echo"]}"#.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let config = ConfigLoader.load(from: url)
    #expect(config.hotkey == "cmd+j")
    #expect(config.tabModifier == "cmd")
    #expect(config.tabs == ["echo"])
}
