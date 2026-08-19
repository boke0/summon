import Foundation
import SummonKit
import Testing

@Test func scanFindsNestedAppsButDoesNotEnterAppBundles() throws {
    let root = try AppsSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let decoded = try AppsSearchScript.search(query: "", roots: root)
    let bundleNames = Set(
        decoded.items.map { URL(fileURLWithPath: $0.subtitle ?? $0.id).lastPathComponent }
    )
    #expect(bundleNames == ["Top.app", "Nested.app", "Deep.app", "Alpha.app"])
    #expect(!bundleNames.contains("Helper.app"))
}

@Test func prefixFilterIsCaseInsensitiveAndAnchored() throws {
    let root = try AppsSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let alpha = try AppsSearchScript.search(query: "Al", roots: root)
    #expect(alpha.items.map(\.title) == ["Alpha"])

    let none = try AppsSearchScript.search(query: "zzz", roots: root)
    #expect(none.items.isEmpty)
}

@Test func actionDryRunParsesAppAndWindow() throws {
    let appJSON = """
    {"id":"app:/tmp/Alpha.app","title":"Alpha","payload":{"kind":"app","path":"/tmp/Alpha.app"}}
    """
    let app = try AppsSearchScript.action(json: appJSON)
    #expect(app.status == 0)
    #expect(app.stdout == "app\t/tmp/Alpha.app\n")

    let windowJSON = """
    {"id":"window:1:0:Docs","title":"Alpha — Docs","payload":{"kind":"window","path":"/tmp/Alpha.app","pid":1,"windowIndex":0,"windowTitle":"Docs"}}
    """
    let window = try AppsSearchScript.action(json: windowJSON)
    #expect(window.status == 0)
    #expect(window.stdout.contains("window\t/tmp/Alpha.app\t1\tDocs"))
}
