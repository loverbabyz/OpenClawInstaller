import Foundation
@testable import OpenClawInstaller

final class MockShellExecutor: ShellExecuting, @unchecked Sendable {

    /// Map of command substring patterns to responses.
    /// The first matching pattern (by insertion order) wins.
    var responses: [(pattern: String, result: ShellResult)] = []

    /// Default result when no pattern matches.
    var defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)

    /// Every command that was executed (for assertion).
    private(set) var executedCommands: [String] = []

    /// Streaming command responses: pattern -> (output chunks, exit code).
    var streamingResponses: [(pattern: String, output: String, exitCode: Int32)] = []

    // MARK: - Helpers

    func addResponse(for pattern: String, output: String = "", errorOutput: String = "", exitCode: Int32 = 0) {
        responses.append((pattern, ShellResult(output: output, errorOutput: errorOutput, exitCode: exitCode)))
    }

    func addStreamingResponse(for pattern: String, output: String = "", exitCode: Int32 = 0) {
        streamingResponses.append((pattern, output, exitCode))
    }

    func reset() {
        responses.removeAll()
        streamingResponses.removeAll()
        executedCommands.removeAll()
    }

    func commandsContaining(_ substring: String) -> [String] {
        executedCommands.filter { $0.contains(substring) }
    }

    // MARK: - ShellExecuting

    func run(_ command: String, environment: [String: String]?) async -> ShellResult {
        executedCommands.append(command)
        for (pattern, result) in responses {
            if command.contains(pattern) { return result }
        }
        return defaultResult
    }

    func runStreaming(_ command: String, onOutput: @escaping @Sendable (String) -> Void) async -> Int32 {
        executedCommands.append(command)
        for (pattern, output, exitCode) in streamingResponses {
            if command.contains(pattern) {
                if !output.isEmpty { onOutput(output) }
                return exitCode
            }
        }
        return 0
    }

    func commandExists(_ command: String) async -> Bool {
        let result = await run("which \(command)", environment: nil)
        return result.exitCode == 0
    }

    func getCommandVersion(_ command: String, versionFlag: String = "--version") async -> String? {
        let result = await run("\(command) \(versionFlag)", environment: nil)
        guard result.exitCode == 0 else { return nil }
        return result.output
    }
}
