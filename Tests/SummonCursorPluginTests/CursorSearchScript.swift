import Foundation
import SummonKit

enum CursorSearchScript {
    static var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("plugins/cursor")
    }

    static var url: URL {
        pluginRoot.appendingPathComponent("bin/search")
    }

    static var actionURL: URL {
        pluginRoot.appendingPathComponent("bin/action")
    }

    static var matchURL: URL {
        pluginRoot.appendingPathComponent("lib/match.sh")
    }

    static func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("summon-cursor-scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let alpha = root.appendingPathComponent("@alpha")
        try FileManager.default.createDirectory(
            at: alpha.appendingPathComponent("notebook"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: alpha.appendingPathComponent("widget"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: alpha.appendingPathComponent("widget").appendingPathComponent("src"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: alpha.appendingPathComponent(".hidden"),
            withIntermediateDirectories: true
        )
        try Data().write(to: alpha.appendingPathComponent("notes.txt"))

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("@beta").appendingPathComponent("catalog"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Documents").appendingPathComponent("not-a-candidate"),
            withIntermediateDirectories: true
        )
        try Data().write(to: root.appendingPathComponent("ignored.code-workspace"))

        return root
    }

    static func run(query: String, workspaceDirectory: URL) throws -> (SearchResponse, Data) {
        let result = try runProcess(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [url.path, query],
            stdin: nil,
            extraEnvironment: ["SUMMON_CURSOR_WORKSPACE_DIR": workspaceDirectory.path]
        )
        guard result.status == 0 else {
            throw NSError(
                domain: "CursorSearchScript",
                code: Int(result.status),
                userInfo: [NSLocalizedDescriptionKey: result.stderr]
            )
        }
        return (try CandidateJSON.decodeSearchResponse(from: result.stdout), result.stdout)
    }

    static func action(json: String, dryRun: Bool = true) throws -> (status: Int32, stdout: String, stderr: String) {
        var extra = [String: String]()
        if dryRun {
            extra["SUMMON_CURSOR_DRY_RUN"] = "1"
        }
        let result = try runProcess(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [actionURL.path],
            stdin: Data(json.utf8),
            extraEnvironment: extra
        )
        return (
            result.status,
            String(data: result.stdout, encoding: .utf8) ?? "",
            result.stderr
        )
    }

    static func match(_ arguments: [String]) throws -> Int32 {
        try runProcess(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [matchURL.path] + arguments,
            stdin: nil,
            extraEnvironment: [:]
        ).status
    }

    private struct ProcessResult {
        var status: Int32
        var stdout: Data
        var stderr: String
    }

    private static func runProcess(
        executable: URL,
        arguments: [String],
        stdin: Data?,
        extraEnvironment: [String: String]
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            extraEnvironment,
            uniquingKeysWith: { _, new in new }
        )

        let stdout = Pipe()
        let stderr = Pipe()
        let stdinPipe = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdinPipe
        try process.run()
        if let stdin {
            try stdinPipe.fileHandleForWriting.write(contentsOf: stdin)
        }
        try stdinPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        let out = try stdout.fileHandleForReading.readToEnd() ?? Data()
        let err = try stderr.fileHandleForReading.readToEnd() ?? Data()
        return ProcessResult(
            status: process.terminationStatus,
            stdout: out,
            stderr: String(data: err, encoding: .utf8) ?? ""
        )
    }
}
