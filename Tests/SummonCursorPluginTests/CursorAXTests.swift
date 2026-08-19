import Testing

@Test func agentsWindowTitlesAreNotRaisedForWorkspaceMatch() throws {
    #expect(try CursorSearchScript.match(["is-agents", "Agents"]) == 0)
    #expect(try CursorSearchScript.match(["is-agents", "Cursor Agents"]) == 0)
    #expect(try CursorSearchScript.match(["is-agents", "Switch to Agents Window"]) == 0)
    #expect(try CursorSearchScript.match(["should-raise", "Cursor Agents", "widget"]) != 0)
    #expect(try CursorSearchScript.match(["should-raise", "Agents", "Agents"]) != 0)
}

@Test func editorWindowTitlesMatchingWorkspaceAreRaised() throws {
    #expect(try CursorSearchScript.match(["should-raise", "README.md - widget", "widget"]) == 0)
    #expect(try CursorSearchScript.match(["should-raise", "widget — Cursor", "widget"]) == 0)
    #expect(try CursorSearchScript.match(["should-raise", "catalog — Cursor", "widget"]) != 0)
    #expect(try CursorSearchScript.match(["should-raise", "README.md - widget", ""]) != 0)
}
