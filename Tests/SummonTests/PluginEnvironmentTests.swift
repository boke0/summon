import Testing
@testable import summon

@Test func pluginEnvironmentDropsDryRunAndCursorHostLeaks() {
    let sanitized = PluginProcessEnvironment.sanitized([
        "HOME": "/Users/example",
        "PATH": "/usr/bin:/bin",
        "SUMMON_CURSOR_DRY_RUN": "1",
        "SUMMON_APPS_DRY_RUN": "1",
        "CURSOR_AGENT": "1",
        "CURSOR_LAYOUT": "glass",
        "VSCODE_IPC_HOOK": "/tmp/hook.sock",
        "VSCODE_PID": "1",
        "ELECTRON_RUN_AS_NODE": "1",
        "LANG": "ja_JP.UTF-8",
    ])
    #expect(sanitized["HOME"] == "/Users/example")
    #expect(sanitized["PATH"] == "/usr/bin:/bin")
    #expect(sanitized["LANG"] == "ja_JP.UTF-8")
    #expect(sanitized["SUMMON_CURSOR_DRY_RUN"] == nil)
    #expect(sanitized["SUMMON_APPS_DRY_RUN"] == nil)
    #expect(sanitized["CURSOR_AGENT"] == nil)
    #expect(sanitized["VSCODE_IPC_HOOK"] == nil)
    #expect(sanitized["ELECTRON_RUN_AS_NODE"] == nil)
}
