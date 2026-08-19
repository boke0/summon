import Foundation

/// Case-insensitive prefix matching. Bundled plugins reimplement this in shell.
public enum PrefixMatcher {
    /// Returns true when `query` is a non-empty, case-insensitive prefix of `text`.
    /// An empty query never matches; callers should treat empty as "show all".
    public static func matches(_ text: String, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return text.range(of: query, options: [.caseInsensitive, .anchored]) != nil
    }

    /// Empty `query` returns `items` unchanged. Otherwise keeps elements whose
    /// `name` has `query` as a case-insensitive prefix (1+ characters).
    public static func prefixFilter<T>(
        _ items: [T],
        query: String,
        name: (T) -> String
    ) -> [T] {
        guard !query.isEmpty else { return items }
        return items.filter { matches(name($0), query: query) }
    }
}
