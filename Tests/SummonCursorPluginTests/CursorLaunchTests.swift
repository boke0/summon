import Testing

@Test func classicOpenUsesOnlyClassicFlagAndPath() throws {
    let path = "/tmp/@org/project"
    let json = """
    {"id":"\(path)","title":"@org/project","payload":{"kind":"workspace","path":"\(path)"}}
    """
    let result = try CursorSearchScript.action(json: json)
    #expect(result.status == 0)
    let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)
    #expect(lines.first == "--classic \(path)")
}

@Test func bundledCLIURLIsInsideCursorApp() throws {
    let json = """
    {"id":"/tmp/@org/project","title":"@org/project","payload":{"kind":"workspace","path":"/tmp/@org/project"}}
    """
    let result = try CursorSearchScript.action(json: json)
    #expect(result.status == 0)
    #expect(result.stdout.contains("/Applications/Cursor.app/Contents/Resources/app/bin/cursor"))
}

@Test func agentsMenuTargetsIncludeClosedGlassFileItem() throws {
    let json = """
    {"id":"agents","title":"Agents","payload":{"kind":"agents"}}
    """
    let result = try CursorSearchScript.action(json: json)
    #expect(result.status == 0)
    let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)
    #expect(lines.first == "agents")
    #expect(lines.contains("Window\tCursor Agents"))
    #expect(lines.contains("File\tSwitch to Agents Window"))
    #expect(lines.contains("File\tNew Agents Window"))
}
