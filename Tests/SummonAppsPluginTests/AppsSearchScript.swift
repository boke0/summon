import Foundation
import SummonKit

enum AppsSearchScript {
    static var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("plugins/apps")
    }

    static var searchURL: URL {
        pluginRoot.appendingPathComponent("bin/search")
    }

    static var actionURL: URL {
        pluginRoot.appendingPathComponent("bin/action")
    }

    static func makeFixture() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("summon-apps-scan-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Top.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Vendor/Nested.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Vendor/Deep/Deep.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent(
                "Vendor/Nested.app/Contents/Helpers/Helper.app",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Alpha.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data().write(to: root.appendingPathComponent("readme.txt"))
        return root
    }

    static func search(query: String, roots: URL) throws -> SearchResponse {
        let result = try runProcess(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [searchURL.path, query],
            stdin: nil,
            extraEnvironment: ["SUMMON_APPS_ROOTS": roots.path]
        )
        guard result.status == 0 else {
            throw NSError(
                domain: "AppsSearchScript",
                code: Int(result.status),
                userInfo: [NSLocalizedDescriptionKey: result.stderr]
            )
        }
        return try CandidateJSON.decodeSearchResponse(from: result.stdout)
    }

    static func action(json: String, dryRun: Bool = true) throws -> (status: Int32, stdout: String) {
        var extra = [String: String]()
        if dryRun {
            extra["SUMMON_APPS_DRY_RUN"] = "1"
        }
        let result = try runProcess(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [actionURL.path],
            stdin: Data(json.utf8),
            extraEnvironment: extra
        )
        return (result.status, String(data: result.stdout, encoding: .utf8) ?? "")
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
