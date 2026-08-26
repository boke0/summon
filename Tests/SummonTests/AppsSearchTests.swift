import Foundation
import SummonKit
import Testing

private enum AppsPlugin {
    static var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("plugins/apps")
    }

    static var searchURL: URL {
        pluginRoot.appendingPathComponent("bin/search")
    }

    static func makeFixture() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("summon-apps-scan-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Top.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Vendor/Nested.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Vendor/Deep/Deep.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent(
                "Vendor/Nested.app/Contents/Helpers/Helper.app",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Alpha.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data().write(to: root.appendingPathComponent("readme.txt"))
        return root
    }

    static func search(query: String, roots: URL) throws -> SearchResponse {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [searchURL.path, query]
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["SUMMON_APPS_ROOTS": roots.path],
            uniquingKeysWith: { _, new in new }
        )
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let out = try stdout.fileHandleForReading.readToEnd() ?? Data()
        let err = try stderr.fileHandleForReading.readToEnd() ?? Data()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AppsPlugin",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: String(data: err, encoding: .utf8) ?? "",
                ]
            )
        }
        return try CandidateJSON.decodeSearchResponse(from: out)
    }
}

@Test func scanFindsNestedAppsButDoesNotEnterAppBundles() throws {
    let root = try AppsPlugin.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let decoded = try AppsPlugin.search(query: "", roots: root)
    let bundleNames = Set(
        decoded.items.map { URL(fileURLWithPath: $0.subtitle ?? $0.id).lastPathComponent }
    )
    #expect(bundleNames == ["Top.app", "Nested.app", "Deep.app", "Alpha.app"])
    #expect(!bundleNames.contains("Helper.app"))
}

@Test func appsPrefixFilterIsCaseInsensitiveAndAnchored() throws {
    let root = try AppsPlugin.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let alpha = try AppsPlugin.search(query: "Al", roots: root)
    #expect(alpha.items.map(\.title) == ["Alpha"])

    let none = try AppsPlugin.search(query: "zzz", roots: root)
    #expect(none.items.isEmpty)
}

@Test func appsSearchItemsExposeActionPayload() throws {
    let root = try AppsPlugin.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let decoded = try AppsPlugin.search(query: "Alpha", roots: root)
    #expect(decoded.items.count == 1)
    let item = decoded.items[0]
    #expect(item.payload?["kind"] == .string("app"))
    let path = item.payload?["path"]?.stringValue
    #expect(path?.hasSuffix("/Alpha.app") == true)
    let encoded = try CandidateJSON.encode(item)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    let payload = object?["payload"] as? [String: Any]
    #expect(payload?["kind"] as? String == "app")
    #expect(payload?["path"] as? String == path)
}

private extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}
