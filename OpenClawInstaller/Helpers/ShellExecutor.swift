import Foundation

struct ShellResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

protocol ShellExecuting: Sendable {
    func run(_ command: String, environment: [String: String]?) async -> ShellResult
    func runStreaming(_ command: String, onOutput: @escaping @Sendable (String) -> Void) async -> Int32
    func commandExists(_ command: String) async -> Bool
    func getCommandVersion(_ command: String, versionFlag: String) async -> String?
}

extension ShellExecuting {
    func run(_ command: String) async -> ShellResult {
        await run(command, environment: nil)
    }
    func getCommandVersion(_ command: String) async -> String? {
        await getCommandVersion(command, versionFlag: "--version")
    }
}

final class ShellExecutor: ShellExecuting, @unchecked Sendable {

    static let shared = ShellExecutor()

    /// Full PATH that includes common tool locations.
    /// macOS apps launched from Finder/Dock inherit a minimal PATH,
    /// so we must explicitly include Homebrew, nvm, nodenv, etc.
    private let shellEnv: [String: String]

    private init() {
        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? NSHomeDirectory()

        // Build a comprehensive PATH covering all common tool locations
        let extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.nvm/versions/node/*/bin",  // nvm — resolved below
            "\(home)/.nodenv/shims",
            "\(home)/.nodenv/bin",
            "\(home)/.volta/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.cargo/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]

        // Resolve nvm wildcard: find the highest node version installed
        var resolvedPaths = [String]()
        for p in extraPaths {
            if p.contains("*") {
                let base = (p as NSString).deletingLastPathComponent
                let pattern = (p as NSString).lastPathComponent
                if let children = try? FileManager.default.contentsOfDirectory(atPath: base) {
                    let matches = children.filter { $0.range(of: pattern, options: .regularExpression) != nil || pattern == "*" }
                        .sorted()
                    if let last = matches.last {
                        resolvedPaths.append("\(base)/\(last)")
                    }
                }
            } else {
                resolvedPaths.append(p)
            }
        }

        let existingPath = env["PATH"] ?? ""
        let allPaths = resolvedPaths + existingPath.split(separator: ":").map(String.init)
        // Deduplicate while preserving order
        var seen = Set<String>()
        let uniquePaths = allPaths.filter { seen.insert($0).inserted }
        env["PATH"] = uniquePaths.joined(separator: ":")

        self.shellEnv = env
    }

    func run(_ command: String, environment: [String: String]? = nil) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [shellEnv] in
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                var env = shellEnv
                if let extra = environment {
                    for (key, value) in extra { env[key] = value }
                }
                process.environment = env

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    continuation.resume(returning: ShellResult(
                        output: output, errorOutput: errorOutput,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(returning: ShellResult(
                        output: "", errorOutput: error.localizedDescription, exitCode: -1
                    ))
                }
            }
        }
    }

    func runStreaming(_ command: String, onOutput: @escaping @Sendable (String) -> Void) async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [shellEnv] in
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                process.environment = shellEnv

                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                        onOutput(str)
                    }
                }

                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                        onOutput(str)
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil

                    continuation.resume(returning: process.terminationStatus)
                } catch {
                    onOutput("Error: \(error.localizedDescription)")
                    continuation.resume(returning: -1)
                }
            }
        }
    }

    func commandExists(_ command: String) async -> Bool {
        let result = await run("which \(command)")
        return result.exitCode == 0
    }

    func getCommandVersion(_ command: String, versionFlag: String = "--version") async -> String? {
        let result = await run("\(command) \(versionFlag)")
        guard result.exitCode == 0 else { return nil }
        return result.output
    }
}
