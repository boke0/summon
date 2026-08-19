import Foundation

public struct Hotkey: Equatable, Sendable {
    public var modifiers: Modifier
    public var key: Key

    public init(modifiers: Modifier, key: Key) {
        self.modifiers = modifiers
        self.key = key
    }

    public var carbonKeyCode: UInt32 {
        key.carbonKeyCode
    }

    public var carbonModifiers: UInt32 {
        modifiers.carbonFlags
    }
}

extension Hotkey {
    public struct Modifier: OptionSet, Equatable, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let command = Modifier(rawValue: 1 << 0)
        public static let shift = Modifier(rawValue: 1 << 1)
        public static let option = Modifier(rawValue: 1 << 2)
        public static let control = Modifier(rawValue: 1 << 3)

        /// Carbon `cmdKey` / `shiftKey` / `optionKey` / `controlKey` bits.
        public var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if contains(.command) { flags |= 1 << 8 }
            if contains(.shift) { flags |= 1 << 9 }
            if contains(.option) { flags |= 1 << 11 }
            if contains(.control) { flags |= 1 << 12 }
            return flags
        }
    }

    public struct Key: Equatable, Sendable {
        public var name: String
        public var carbonKeyCode: UInt32

        public init(name: String, carbonKeyCode: UInt32) {
            self.name = name
            self.carbonKeyCode = carbonKeyCode
        }
    }
}

public enum HotkeyParseError: Error, Equatable, Sendable {
    case empty
    case missingKey
    case missingModifier
    case unknownToken(String)
}

public enum HotkeyParser {
    public static func parse(_ string: String) throws -> Hotkey {
        let tokens = tokenize(string)
        guard !tokens.isEmpty else { throw HotkeyParseError.empty }
        guard tokens.count >= 2 else { throw HotkeyParseError.missingKey }

        let keyToken = tokens[tokens.count - 1]
        let modifierTokens = tokens.dropLast()
        guard let key = Self.key(from: keyToken) else {
            throw HotkeyParseError.unknownToken(keyToken)
        }
        let modifiers = try parseModifierTokens(Array(modifierTokens))
        guard !modifiers.isEmpty else { throw HotkeyParseError.missingModifier }
        return Hotkey(modifiers: modifiers, key: key)
    }

    /// Parses a modifier-only string such as `"cmd"` or `"cmd+shift"`.
    public static func parseModifiers(_ string: String) throws -> Hotkey.Modifier {
        let tokens = tokenize(string)
        guard !tokens.isEmpty else { throw HotkeyParseError.empty }
        return try parseModifierTokens(tokens)
    }

    private static func tokenize(_ string: String) -> [String] {
        string
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func parseModifierTokens(_ tokens: [String]) throws -> Hotkey.Modifier {
        var modifiers: Hotkey.Modifier = []
        for token in tokens {
            guard let modifier = Self.modifier(from: token) else {
                throw HotkeyParseError.unknownToken(token)
            }
            modifiers.insert(modifier)
        }
        return modifiers
    }

    private static func modifier(from token: String) -> Hotkey.Modifier? {
        switch token {
        case "cmd", "command", "meta":
            return .command
        case "shift":
            return .shift
        case "opt", "option", "alt":
            return .option
        case "ctrl", "control":
            return .control
        default:
            return nil
        }
    }

    private static func key(from token: String) -> Hotkey.Key? {
        switch token {
        case "space":
            return Hotkey.Key(name: "space", carbonKeyCode: 0x31)
        case "enter", "return":
            return Hotkey.Key(name: "return", carbonKeyCode: 0x24)
        case "esc", "escape":
            return Hotkey.Key(name: "escape", carbonKeyCode: 0x35)
        case "tab":
            return Hotkey.Key(name: "tab", carbonKeyCode: 0x30)
        default:
            guard token.count == 1, let character = token.first else { return nil }
            guard let code = ansiKeyCodes[character] else { return nil }
            return Hotkey.Key(name: String(character), carbonKeyCode: code)
        }
    }
}

/// ANSI virtual-key codes (HIToolbox `kVK_ANSI_*` / `kVK_Space`).
private let ansiKeyCodes: [Character: UInt32] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B,
    "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
    "9": 0x19, "7": 0x1A, "8": 0x1C, "0": 0x1D,
    "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23,
    "l": 0x25, "j": 0x26, "k": 0x28,
    "n": 0x2D, "m": 0x2E,
]
