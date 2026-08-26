import Foundation
import SummonKit

enum PluginProcessError: Error, Sendable {
    case missingExecutable(URL)
    case invalidJSON(Error)
}

enum PluginProcessEnvironment {
    /// Drops variables inherited from Cursor's agent/extension-host or from
    /// plugin test harnesses. Those leaks make action scripts no-op (dry-run)
    /// or prevent `cursor` from opening a real window.
    static func sanitized(_ environment: [String: String]) -> [String: String] {
        environment.filter { key, _ in !isHostOnly(key) }
    }

    static func isHostOnly(_ key: String) -> Bool {
        if key.hasPrefix("VSCODE_") { return true }
        if key.hasPrefix("ELECTRON_") { return true }
        if key.hasPrefix("SUMMON_"), key.hasSuffix("_DRY_RUN") { return true }
        switch key {
        case "CURSOR_AGENT", "CURSOR_LAYOUT", "CURSOR_CONVERSATION_ID",
             "CURSOR_WORKSPACE_LABEL":
            return true
        default:
            return false
        }
    }
}

enum PluginProcess {
    struct Output: Sendable {
        var data: Data
        var status: Int32
    }

    static func search(plugin: LoadedPlugin, query: String) async throws -> [Candidate] {
        let output = try await run(
            executable: plugin.searchExecutable,
            arguments: plugin.searchArguments + [query],
            currentDirectory: plugin.directory,
            stdin: nil
        )
        if Task.isCancelled { throw CancellationError() }
        let trimmed = output.data.trimmingUTF8Whitespace
        if trimmed.isEmpty {
            return []
        }
        do {
            return try CandidateJSON.decodeSearchResponse(from: trimmed).items
        } catch {
            throw PluginProcessError.invalidJSON(error)
        }
    }

    static func action(plugin: LoadedPlugin, candidate: Candidate) async throws -> Int32 {
        let stdin = try CandidateJSON.encode(candidate)
        let output = try await run(
            executable: plugin.actionExecutable,
            arguments: plugin.actionArguments,
            currentDirectory: plugin.directory,
            stdin: stdin
        )
        if Task.isCancelled { throw CancellationError() }
        return output.status
    }

    static func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL,
        stdin: Data?
    ) async throws -> Output {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw PluginProcessError.missingExecutable(executable)
        }

        let box = ProcessBox()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectory
                process.environment = PluginProcessEnvironment.sanitized(
                    ProcessInfo.processInfo.environment
                )

                let stdout = Pipe()
                let stdinPipe = Pipe()
                process.standardOutput = stdout
                process.standardInput = stdinPipe
                process.standardError = FileHandle.standardError

                try box.launch(process)
                if let stdin {
                    try stdinPipe.fileHandleForWriting.write(contentsOf: stdin)
                }
                try stdinPipe.fileHandleForWriting.close()

                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if Task.isCancelled {
                    throw CancellationError()
                }
                return Output(data: data, status: process.terminationStatus)
            }.value
        } onCancel: {
            box.terminate()
        }
    }
}

final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var inner: Process?
    private var cancelled = false

    func launch(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else {
            throw CancellationError()
        }
        try process.run()
        inner = process
    }

    func terminate() {
        lock.lock()
        cancelled = true
        let process = inner
        lock.unlock()
        if process?.isRunning == true {
            process?.terminate()
        }
    }
}

private extension Data {
    var trimmingUTF8Whitespace: Data {
        guard let string = String(data: self, encoding: .utf8) else { return self }
        return Data(string.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }
}
