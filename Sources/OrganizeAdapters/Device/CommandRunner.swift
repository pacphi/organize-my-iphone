import Foundation
import Subprocess
import System

/// The outcome of running an external program.
public struct CommandResult: Hashable, Sendable {
    public var succeeded: Bool
    public var standardOutput: String
    public var standardError: String

    public init(succeeded: Bool, standardOutput: String, standardError: String = "") {
        self.succeeded = succeeded
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// Runs external programs. The real implementation spawns a process; tests substitute a fake.
public protocol CommandRunning: Sendable {
    /// - Parameters:
    ///   - executable: Absolute path of the program to run.
    ///   - arguments: Arguments, passed as-is with no shell in between.
    func execute(_ executable: String, arguments: [String]) async throws -> CommandResult
}

/// Runs programs with swift-subprocess.
public struct SubprocessCommandRunner: CommandRunning {
    /// Upper bound on captured standard output, in bytes.
    public let outputLimit: Int

    public init(outputLimit: Int = 32 * 1024 * 1024) {
        self.outputLimit = outputLimit
    }

    public func execute(_ executable: String, arguments: [String]) async throws -> CommandResult {
        let result = try await run(
            .path(FilePath(executable)),
            arguments: Arguments(arguments),
            output: .string(limit: outputLimit),
            error: .string(limit: 1024 * 1024)
        )
        return CommandResult(
            succeeded: result.terminationStatus.isSuccess,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }
}
