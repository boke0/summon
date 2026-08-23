import Foundation
import Testing
@testable import SummonKit

@Test func decodeManifest() throws {
    let json = """
    {"name":"apps","title":"Apps","search":["bin/search"],"action":["bin/action"]}
    """
    let manifest = try PluginManifestJSON.decode(from: Data(json.utf8))
    #expect(manifest.name == "apps")
    #expect(manifest.title == "Apps")
    #expect(manifest.search == ["bin/search"])
    #expect(manifest.action == ["bin/action"])
}

@Test func decodeManifestWithInterpreter() throws {
    let json = """
    {"name":"echo","title":"Echo","search":["/usr/bin/python3","search.py"],"action":["bin/action"]}
    """
    let manifest = try PluginManifestJSON.decode(from: Data(json.utf8))
    #expect(manifest.search == ["/usr/bin/python3", "search.py"])
}

@Test func decodeManifestRejectsEmptySearch() {
    let json = #"{"name":"x","title":"X","search":[],"action":["bin/action"]}"#
    #expect(throws: PluginContractError.emptyCommand("search")) {
        try PluginManifestJSON.decode(from: Data(json.utf8))
    }
}

@Test func decodeManifestRejectsEmptyName() {
    let json = #"{"name":"","title":"X","search":["bin/search"],"action":["bin/action"]}"#
    #expect(throws: PluginContractError.emptyField("name")) {
        try PluginManifestJSON.decode(from: Data(json.utf8))
    }
}

@Test func echoPluginManifestOnDisk() throws {
    let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let manifestURL = testsDir
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Examples/echo-plugin/plugin.json")
    let data = try Data(contentsOf: manifestURL)
    let manifest = try PluginManifestJSON.decode(from: data)
    #expect(manifest.name == "echo")
    #expect(manifest.title == "Echo")
    #expect(manifest.search == ["bin/search"])
    #expect(manifest.action == ["bin/action"])
}

@Test func appsPluginManifestOnDisk() throws {
    let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let manifestURL = testsDir
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("plugins/apps/plugin.json")
    let data = try Data(contentsOf: manifestURL)
    let manifest = try PluginManifestJSON.decode(from: data)
    #expect(manifest.name == "apps")
    #expect(manifest.title == "Apps")
    #expect(manifest.search == ["bin/search"])
    #expect(manifest.action == ["bin/action"])
}

@Test func cursorPluginManifestOnDisk() throws {
    let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let manifestURL = testsDir
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("plugins/cursor/plugin.json")
    let data = try Data(contentsOf: manifestURL)
    let manifest = try PluginManifestJSON.decode(from: data)
    #expect(manifest.name == "cursor")
    #expect(manifest.title == "Cursor")
    #expect(manifest.search == ["bin/search"])
    #expect(manifest.action == ["bin/action"])
}
