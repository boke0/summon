import Foundation
import Testing

@Test func cursorActionDoesNotClickAgentsWindowContent() throws {
    let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let actionURL = testsDir
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("plugins/cursor/bin/action")
    let source = try String(contentsOf: actionURL, encoding: .utf8)

    #expect(source.contains("focus_cursor_window \"$title\" 0"))
    #expect(source.contains("focus_cursor_window \"\" 0"))
    #expect(source.contains("if focus_cursor_window \"\"; then"))
}
