import Foundation
import SummonKit
import Testing

@Test func listsTopLevelAtOrgProjectsOnly() throws {
    let root = try CursorSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let (decoded, _) = try CursorSearchScript.run(query: "", workspaceDirectory: root)
    let titles = decoded.items.map(\.title)
    #expect(titles == ["@alpha/notebook", "@alpha/widget", "@beta/catalog", "Agents"])
    #expect(decoded.items.dropLast().allSatisfy { item in
        item.payload?["kind"] == .string("workspace") && (item.subtitle?.hasPrefix(root.path) ?? false)
    })
    #expect(!titles.contains { $0.contains(".hidden") })
    #expect(!titles.contains { $0.contains("src") })
    #expect(!titles.contains { $0.contains("Documents") })
    #expect(!titles.contains { $0.contains("code-workspace") })
}

@Test func searchUsesOverridableWorkspaceDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-cursor-home-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("@alpha").appendingPathComponent("notebook"),
        withIntermediateDirectories: true
    )

    let (decoded, _) = try CursorSearchScript.run(query: "", workspaceDirectory: root)
    #expect(decoded.items.map(\.title) == ["@alpha/notebook", "Agents"])
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
