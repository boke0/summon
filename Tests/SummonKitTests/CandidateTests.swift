import Foundation
import Testing
@testable import SummonKit

@Test func decodeSearchResponse() throws {
    let json = """
    {
      "items": [
        {
          "id": "safari",
          "title": "Safari",
          "subtitle": "Browser",
          "icon": "/Applications/Safari.app",
          "payload": {"kind": "app", "count": 1, "ok": true}
        }
      ]
    }
    """
    let response = try CandidateJSON.decodeSearchResponse(from: Data(json.utf8))
    #expect(response.items.count == 1)
    let item = response.items[0]
    #expect(item.id == "safari")
    #expect(item.title == "Safari")
    #expect(item.subtitle == "Browser")
    #expect(item.icon == "/Applications/Safari.app")
    #expect(item.payload?["kind"] == .string("app"))
    #expect(item.payload?["count"] == .number(1))
    #expect(item.payload?["ok"] == .bool(true))
}

@Test func decodeSearchResponseOptionalFields() throws {
    let json = #"{"items":[{"id":"x","title":"X"}]}"#
    let response = try CandidateJSON.decodeSearchResponse(from: Data(json.utf8))
    #expect(response.items[0].subtitle == nil)
    #expect(response.items[0].icon == nil)
    #expect(response.items[0].payload == nil)
}

@Test func encodeCandidateRoundTrip() throws {
    let candidate = Candidate(
        id: "echo",
        title: "hi",
        subtitle: "sub",
        payload: ["text": .string("hi"), "n": .number(2)]
    )
    let data = try CandidateJSON.encode(candidate)
    let decoded = try JSONDecoder().decode(Candidate.self, from: data)
    #expect(decoded == candidate)
}

@Test func decodeSearchResponseRejectsMissingTitle() {
    let json = #"{"items":[{"id":"x"}]}"#
    #expect(throws: DecodingError.self) {
        try CandidateJSON.decodeSearchResponse(from: Data(json.utf8))
    }
}
