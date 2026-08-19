import Testing
@testable import SummonKit

@Test func parseDefaultHotkey() throws {
    let hotkey = try HotkeyParser.parse("cmd+d")
    #expect(hotkey.modifiers == .command)
    #expect(hotkey.key.name == "d")
    #expect(hotkey.carbonKeyCode == 0x02)
    #expect(hotkey.carbonModifiers == 1 << 8)
}

@Test func parseHotkeyIsCaseInsensitive() throws {
    let hotkey = try HotkeyParser.parse("CMD+SHIFT+A")
    #expect(hotkey.modifiers == [.command, .shift])
    #expect(hotkey.key.name == "a")
    #expect(hotkey.carbonKeyCode == 0x00)
    #expect(hotkey.carbonModifiers == (1 << 8) | (1 << 9))
}

@Test func parseHotkeyAliases() throws {
    let command = try HotkeyParser.parse("command+space")
    #expect(command.modifiers == .command)
    #expect(command.carbonKeyCode == 0x31)

    let option = try HotkeyParser.parse("alt+1")
    #expect(option.modifiers == .option)
    #expect(option.carbonModifiers == 1 << 11)

    let control = try HotkeyParser.parse("ctrl+escape")
    #expect(control.modifiers == .control)
    #expect(control.carbonKeyCode == 0x35)
    #expect(control.carbonModifiers == 1 << 12)
}

@Test func parseModifiersOnly() throws {
    #expect(try HotkeyParser.parseModifiers("cmd") == .command)
    #expect(try HotkeyParser.parseModifiers("cmd+shift") == [.command, .shift])
    #expect(try HotkeyParser.parseModifiers("opt") == .option)
}

@Test func parseHotkeyErrors() {
    #expect(throws: HotkeyParseError.empty) {
        try HotkeyParser.parse("   ")
    }
    #expect(throws: HotkeyParseError.missingKey) {
        try HotkeyParser.parse("cmd")
    }
    #expect(throws: HotkeyParseError.unknownToken("super")) {
        try HotkeyParser.parse("super+d")
    }
    #expect(throws: HotkeyParseError.unknownToken("f13")) {
        try HotkeyParser.parse("cmd+f13")
    }
    #expect(throws: HotkeyParseError.unknownToken("d")) {
        try HotkeyParser.parseModifiers("cmd+d")
    }
}
