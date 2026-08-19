import Testing
@testable import summon

@Test func candidateListIDsAreUniqueAcrossPlugins() {
    let cursor = CandidateListID.row(plugin: "cursor", candidateID: "1")
    let apps = CandidateListID.row(plugin: "apps", candidateID: "1")
    #expect(cursor != apps)
    #expect(cursor == CandidateListID.row(plugin: "cursor", candidateID: "1"))
}
