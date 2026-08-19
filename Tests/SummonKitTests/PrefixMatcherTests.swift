import Testing
@testable import SummonKit

@Test func prefixMatchIsCaseInsensitive() {
    #expect(PrefixMatcher.matches("Safari", query: "s"))
    #expect(PrefixMatcher.matches("Safari", query: "S"))
    #expect(PrefixMatcher.matches("Safari", query: "saf"))
    #expect(PrefixMatcher.matches("Safari", query: "SAFARI"))
    #expect(PrefixMatcher.matches("Cursor", query: "c"))
}

@Test func prefixMatchRequiresPrefix() {
    #expect(!PrefixMatcher.matches("Safari", query: "afari"))
    #expect(!PrefixMatcher.matches("Safari", query: "ari"))
    #expect(!PrefixMatcher.matches("Cursor", query: "u"))
    #expect(!PrefixMatcher.matches("Safari", query: "SafariX"))
}

@Test func prefixMatchRequiresAtLeastOneCharacter() {
    #expect(!PrefixMatcher.matches("Safari", query: ""))
    #expect(PrefixMatcher.matches("Safari", query: "S"))
}

@Test func prefixMatchUnicode() {
    #expect(PrefixMatcher.matches("あいうえお", query: "あ"))
    #expect(PrefixMatcher.matches("あいうえお", query: "あい"))
    #expect(!PrefixMatcher.matches("あいうえお", query: "いう"))
}

@Test func prefixFilterEmptyQueryReturnsAll() {
    let names = ["Safari", "Cursor", "Mail"]
    #expect(PrefixMatcher.prefixFilter(names, query: "", name: { $0 }) == names)
}

@Test func prefixFilterKeepsCaseInsensitivePrefixes() {
    let names = ["Safari", "System Settings", "Cursor", "Mail"]
    #expect(
        PrefixMatcher.prefixFilter(names, query: "s", name: { $0 })
            == ["Safari", "System Settings"]
    )
    #expect(PrefixMatcher.prefixFilter(names, query: "cu", name: { $0 }) == ["Cursor"])
    #expect(PrefixMatcher.prefixFilter(names, query: "x", name: { $0 }).isEmpty)
}

@Test func prefixFilterUsesNameClosure() {
    struct Item {
        var id: String
        var title: String
    }
    let items = [
        Item(id: "1", title: "Safari"),
        Item(id: "2", title: "Mail"),
    ]
    let filtered = PrefixMatcher.prefixFilter(items, query: "sa", name: \.title)
    #expect(filtered.map(\.id) == ["1"])
}
