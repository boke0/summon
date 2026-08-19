import Foundation
import Testing
@testable import SummonKit

@Test func loadPluginsUserOverridesBundled() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-plugins-\(UUID().uuidString)")
    let bundled = root.appendingPathComponent("bundled")
    let user = root.appendingPathComponent("user")
    defer { try? FileManager.default.removeItem(at: root) }

    try writePlugin(named: "echo", title: "Bundled Echo", in: bundled)
    try writePlugin(named: "apps", title: "Apps", in: bundled)
    try writePlugin(named: "echo", title: "User Echo", in: user)

    let loaded = PluginLoader.load(bundledDirectory: bundled, userDirectory: user)
    let echo = loaded.first { $0.manifest.name == "echo" }
    let apps = loaded.first { $0.manifest.name == "apps" }
    #expect(loaded.count == 2)
    #expect(echo?.manifest.title == "User Echo")
    #expect(echo?.source == .user)
    #expect(apps?.manifest.title == "Apps")
    #expect(apps?.source == .bundled)
}

@Test func resolveTabsFiltersAndOrders() throws {
    let plugins = [
        LoadedPlugin(
            manifest: PluginManifest(name: "echo", title: "Echo", search: ["s"], action: ["a"]),
            directory: URL(fileURLWithPath: "/tmp/echo"),
            source: .bundled
        ),
        LoadedPlugin(
            manifest: PluginManifest(name: "apps", title: "Apps", search: ["s"], action: ["a"]),
            directory: URL(fileURLWithPath: "/tmp/apps"),
            source: .bundled
        ),
        LoadedPlugin(
            manifest: PluginManifest(name: "cursor", title: "Cursor", search: ["s"], action: ["a"]),
            directory: URL(fileURLWithPath: "/tmp/cursor"),
            source: .bundled
        ),
    ]

    let ordered = PluginResolver.tabs(from: plugins, orderedBy: ["cursor", "apps"])
    #expect(ordered.map(\.manifest.name) == ["cursor", "apps"])
}

@Test func resolveTabsFallsBackWhenNoneMatch() throws {
    let plugins = [
        LoadedPlugin(
            manifest: PluginManifest(name: "echo", title: "Echo", search: ["s"], action: ["a"]),
            directory: URL(fileURLWithPath: "/tmp/echo"),
            source: .bundled
        ),
    ]
    let tabs = PluginResolver.tabs(from: plugins, orderedBy: ["apps", "cursor"])
    #expect(tabs.map(\.manifest.name) == ["echo"])
}

@Test func scanSkipsInvalidDirectories() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-scan-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir.appendingPathComponent("empty"), withIntermediateDirectories: true)
    try writePlugin(named: "echo", title: "Echo", in: dir)

    let scanned = PluginLoader.scan(dir, source: .bundled)
    #expect(scanned.count == 1)
    #expect(scanned[0].manifest.name == "echo")
    #expect(scanned[0].searchExecutable.lastPathComponent == "search")
}

private func writePlugin(named name: String, title: String, in root: URL) throws {
    let dir = root.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: dir.appendingPathComponent("bin"), withIntermediateDirectories: true)
    let json = """
    {"name":"\(name)","title":"\(title)","search":["bin/search"],"action":["bin/action"]}
    """
    try Data(json.utf8).write(to: dir.appendingPathComponent("plugin.json"))
}
