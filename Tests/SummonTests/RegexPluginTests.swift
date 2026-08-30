import Foundation
import SummonKit
import Testing

private enum RegexPlugin {
    static var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("plugins/regex")
    }

    static var searchURL: URL {
        pluginRoot.appendingPathComponent("bin/search")
    }

    static var actionURL: URL {
        pluginRoot.appendingPathComponent("bin/action")
    }

    static func search(
        query: String,
        seed: String? = "1",
        count: Int? = nil
    ) throws -> SearchResponse {
        let process = Process()
        process.executableURL = searchURL
        process.arguments = [query]
        var environment = ProcessInfo.processInfo.environment
        if let seed {
            environment["SUMMON_REGEX_SEED"] = seed
        }
        if let count {
            environment["SUMMON_REGEX_COUNT"] = String(count)
        }
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let out = try stdout.fileHandleForReading.readToEnd() ?? Data()
        let err = try stderr.fileHandleForReading.readToEnd() ?? Data()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "RegexPlugin",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: String(data: err, encoding: .utf8) ?? "",
                ]
            )
        }
        return try CandidateJSON.decodeSearchResponse(from: out)
    }

    static func action(candidate: Candidate, output: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = actionURL
        process.arguments = []
        var environment = ProcessInfo.processInfo.environment
        environment["SUMMON_REGEX_ACTION_OUT"] = output.path
        process.environment = environment
        let stdin = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderr
        try process.run()
        try stdin.fileHandleForWriting.write(contentsOf: CandidateJSON.encode(candidate))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let err = try stderr.fileHandleForReading.readToEnd() ?? Data()
            throw NSError(
                domain: "RegexPlugin",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: String(data: err, encoding: .utf8) ?? "",
                ]
            )
        }
        return process.terminationStatus
    }
}

private extension Candidate {
    var payloadKind: String? {
        payload?["kind"]?.stringValue
    }

    var payloadText: String? {
        payload?["text"]?.stringValue
    }
}

private extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

@Test func regexScriptsUseEnvPythonShebang() throws {
    let search = try String(contentsOf: RegexPlugin.searchURL, encoding: .utf8)
    let action = try String(contentsOf: RegexPlugin.actionURL, encoding: .utf8)
    #expect(search.hasPrefix("#!/usr/bin/env python3"))
    #expect(action.hasPrefix("#!/usr/bin/env python3"))
}

@Test func regexEmptyQueryReturnsExampleStrings() throws {
    let decoded = try RegexPlugin.search(query: "")
    #expect(!decoded.items.isEmpty)
    #expect(decoded.items.allSatisfy { $0.payloadKind == "text" })
    #expect(Set(decoded.items.map(\.id)).count == decoded.items.count)
    #expect(decoded.items.allSatisfy { ($0.payloadText?.isEmpty == false) })
}

@Test func regexGeneratesStringsMatchingThePattern() throws {
    let decoded = try RegexPlugin.search(query: "[a-z]{8}", count: 8)
    #expect(decoded.items.count == 8)
    let texts = decoded.items.compactMap(\.payloadText)
    #expect(Set(texts).count == 8)
    let regex = try Regex("[a-z]{8}")
    for item in decoded.items {
        let text = try #require(item.payloadText)
        #expect(text.wholeMatch(of: regex) != nil)
        #expect(item.title == text)
        #expect(item.payloadKind == "text")
        #expect(item.subtitle == "Copy to clipboard")
    }
}

@Test func regexSearchIsDeterministicForAFixedSeed() throws {
    let first = try RegexPlugin.search(query: #"\d{4}-\d{4}"#, seed: "42", count: 5)
    let second = try RegexPlugin.search(query: #"\d{4}-\d{4}"#, seed: "42", count: 5)
    #expect(first.items.map(\.payloadText) == second.items.map(\.payloadText))
    let regex = try Regex(#"\d{4}-\d{4}"#)
    for item in first.items {
        let text = try #require(item.payloadText)
        #expect(text.wholeMatch(of: regex) != nil)
    }
}

@Test func regexLiteralPatternReturnsThatString() throws {
    let decoded = try RegexPlugin.search(query: "hello")
    #expect(decoded.items.map(\.payloadText) == ["hello"])
}

@Test func regexAlternationOnlyEmitsListedBranches() throws {
    let decoded = try RegexPlugin.search(query: "foo|bar", count: 8)
    let texts = Set(decoded.items.compactMap(\.payloadText))
    #expect(!texts.isEmpty)
    #expect(texts.isSubset(of: ["foo", "bar"]))
}

@Test func regexBackreferenceRepeatsTheCapturedGroup() throws {
    let decoded = try RegexPlugin.search(query: #"([ab])\1"#, count: 4)
    #expect(!decoded.items.isEmpty)
    for item in decoded.items {
        #expect(["aa", "bb"].contains(item.payloadText))
    }
}

@Test func regexInvalidPatternReturnsAnErrorItem() throws {
    let decoded = try RegexPlugin.search(query: "(")
    #expect(decoded.items.count == 1)
    #expect(decoded.items[0].payloadKind == "error")
    #expect(decoded.items[0].title == "Invalid regular expression")
    #expect(decoded.items[0].subtitle?.isEmpty == false)
}

@Test func regexImpossiblePatternReturnsAnErrorItem() throws {
    let decoded = try RegexPlugin.search(query: #"(?!x)x"#)
    #expect(decoded.items.count == 1)
    #expect(decoded.items[0].payloadKind == "error")
    #expect(decoded.items[0].title == "Could not generate a matching string")
}

@Test func regexActionWritesPayloadText() throws {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-regex-action-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: output) }

    let candidate = try #require(try RegexPlugin.search(query: "hello").items.first)
    let status = try RegexPlugin.action(candidate: candidate, output: output)
    #expect(status == 0)
    let copied = try String(contentsOf: output, encoding: .utf8)
    #expect(copied == "hello")
}

@Test func regexActionIgnoresNonTextPayloads() throws {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-regex-action-\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: output) }

    let candidate = Candidate(
        id: "error",
        title: "Invalid regular expression",
        subtitle: "missing )",
        payload: ["kind": .string("error")]
    )
    let status = try RegexPlugin.action(candidate: candidate, output: output)
    #expect(status == 0)
    #expect(!FileManager.default.fileExists(atPath: output.path))
}
