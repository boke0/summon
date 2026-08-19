import Foundation

public struct Candidate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var icon: String?
    public var payload: [String: JSONValue]?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        payload: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.payload = payload
    }
}

public struct SearchResponse: Codable, Equatable, Sendable {
    public var items: [Candidate]

    public init(items: [Candidate]) {
        self.items = items
    }
}

public enum CandidateJSON {
    public static func decodeSearchResponse(from data: Data) throws -> SearchResponse {
        try JSONDecoder().decode(SearchResponse.self, from: data)
    }

    public static func encode(_ candidate: Candidate) throws -> Data {
        try JSONEncoder().encode(candidate)
    }
}
