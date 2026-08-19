import Foundation
import SummonKit
import Testing

@Test func emptyQueryIncludesWorkspacesAndAgents() throws {
    let root = try CursorSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let (decoded, _) = try CursorSearchScript.run(query: "", workspaceDirectory: root)
    #expect(decoded.items.map(\.title) == ["@alpha/notebook", "@alpha/widget", "@beta/catalog", "Agents"])
    #expect(decoded.items.last?.id == "agents")
    #expect(decoded.items.last?.payload?["kind"] == .string("agents"))
}

@Test func substringFilterIsCaseInsensitive() throws {
    let root = try CursorSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let widget = try CursorSearchScript.run(query: "wid", workspaceDirectory: root).0
    #expect(widget.items.map(\.title) == ["@alpha/widget"])

    let widgetUpper = try CursorSearchScript.run(query: "WID", workspaceDirectory: root).0
    #expect(widgetUpper.items.map(\.title) == ["@alpha/widget"])

    let org = try CursorSearchScript.run(query: "@alpha", workspaceDirectory: root).0
    #expect(org.items.map(\.title) == ["@alpha/notebook", "@alpha/widget"])

    let notebook = try CursorSearchScript.run(query: "note", workspaceDirectory: root).0
    #expect(notebook.items.map(\.title) == ["@alpha/notebook"])

    let middle = try CursorSearchScript.run(query: "tal", workspaceDirectory: root).0
    #expect(middle.items.map(\.title) == ["@beta/catalog"])

    let agents = try CursorSearchScript.run(query: "ag", workspaceDirectory: root).0
    #expect(agents.items.map(\.title) == ["Agents"])

    let none = try CursorSearchScript.run(query: "zzz", workspaceDirectory: root).0
    #expect(none.items.isEmpty)
}

@Test func substringFilterDoesNotSearchPath() throws {
    let root = try CursorSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let leaked = try CursorSearchScript.run(query: "summon-cursor-scan", workspaceDirectory: root).0
    #expect(leaked.items.isEmpty)
}

@Test func candidateJSONRoundTrip() throws {
    let root = try CursorSearchScript.makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let (decoded, data) = try CursorSearchScript.run(query: "", workspaceDirectory: root)
    let first = decoded.items[0]
    #expect(first.title == "@alpha/notebook")
    #expect(first.subtitle?.hasSuffix("/@alpha/notebook") == true)
    #expect(first.id == first.subtitle)
    #expect(first.icon == "/Applications/Cursor.app")
    #expect(first.payload?["kind"] == .string("workspace"))
    #expect(first.payload?["path"] == .string(first.id))
    #expect(decoded.items.last?.id == "agents")
    #expect(decoded.items.last?.title == "Agents")
    #expect(decoded.items.last?.payload?["kind"] == .string("agents"))

    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(object?["items"] is [Any])
}

@Test func quotedDirectoryNameRoundTripsInJSON() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-cursor-quote-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("@gamma").appendingPathComponent("quote\"ed"),
        withIntermediateDirectories: true
    )

    let decoded = try CursorSearchScript.run(query: "", workspaceDirectory: root).0
    #expect(decoded.items[0].title == "@gamma/quote\"ed")
    #expect(decoded.items[0].id.hasSuffix("/@gamma/quote\"ed"))
}

@Test func parseWorkspaceAndAgentsActions() throws {
    let workspace = Candidate(
        id: "/tmp/@org/project",
        title: "@org/project",
        payload: [
            "kind": .string("workspace"),
            "path": .string("/tmp/@org/project"),
        ]
    )
    let workspaceJSON = String(data: try JSONEncoder().encode(workspace), encoding: .utf8)!
    let workspaceOut = try CursorSearchScript.action(json: workspaceJSON)
    #expect(workspaceOut.status == 0)
    #expect(workspaceOut.stdout.contains("--classic /tmp/@org/project"))

    let agents = Candidate(
        id: "agents",
        title: "Agents",
        payload: ["kind": .string("agents")]
    )
    let agentsJSON = String(data: try JSONEncoder().encode(agents), encoding: .utf8)!
    let agentsOut = try CursorSearchScript.action(json: agentsJSON)
    #expect(agentsOut.status == 0)
    #expect(agentsOut.stdout.split(whereSeparator: \.isNewline).first.map(String.init) == "agents")

    let agentsByID = Candidate(id: "agents", title: "Agents")
    let agentsByIDJSON = String(data: try JSONEncoder().encode(agentsByID), encoding: .utf8)!
    let agentsByIDOut = try CursorSearchScript.action(json: agentsByIDJSON)
    #expect(agentsByIDOut.status == 0)
    #expect(agentsByIDOut.stdout.contains("agents"))
}

@Test func parseActionRejectsMissingWorkspacePath() throws {
    let candidate = Candidate(
        id: "x",
        title: "x",
        payload: ["kind": .string("workspace")]
    )
    let json = String(data: try JSONEncoder().encode(candidate), encoding: .utf8)!
    let result = try CursorSearchScript.action(json: json)
    #expect(result.status != 0)
}
