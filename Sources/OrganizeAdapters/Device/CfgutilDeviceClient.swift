import Foundation
import OrganizeCore

/// Talks to an iPhone through Apple Configurator's `cfgutil`.
///
/// Commands used:
///
///     cfgutil --format JSON list
///     cfgutil --format JSON [-e ECID] get installedApps
///     cfgutil [-e ECID] get-icon-layout
///     cfgutil [-e ECID] set-icon-layout <file>
///
/// The Apple Configurator window must be closed while these run, or cfgutil reports the
/// device as in use.
public struct CfgutilDeviceClient: DeviceClient {
    public let executable: String
    public let runner: any CommandRunning
    public let temporaryDirectory: URL

    public init(
        executable: String,
        runner: any CommandRunning = SubprocessCommandRunner(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.executable = executable
        self.runner = runner
        self.temporaryDirectory = temporaryDirectory
    }

    public func listDevices() async throws -> [ConnectedDevice] {
        let envelope = try await runForEnvelope(["--format", "JSON", "list"])
        return CfgutilParser.parseDevices(envelope)
    }

    public func installedApps(ecid: String?) async throws -> [AppRecord] {
        let arguments = ["--format", "JSON"] + selector(ecid) + ["get", "installedApps"]
        let envelope = try await runForEnvelope(arguments)
        return try CfgutilParser.parseInstalledApps(envelope, ecid: ecid)
    }

    public func iconLayout(ecid: String?) async throws -> IconLayout {
        let result = try await runner.execute(executable, arguments: selector(ecid) + ["get-icon-layout"])
        guard result.succeeded else {
            throw DeviceError.commandFailed(message: failureMessage(result))
        }
        do {
            return try IconLayoutCodec.decode(text: result.standardOutput)
        } catch {
            throw DeviceError.malformedOutput(String(result.standardOutput.prefix(200)))
        }
    }

    public func applyIconLayout(_ layout: IconLayout, ecid: String?) async throws {
        let file = temporaryDirectory.appendingPathComponent("organize-my-iphone-\(UUID().uuidString).json")
        try IconLayoutCodec.encodeData(layout).write(to: file, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: file)
        }

        let result = try await runner.execute(executable, arguments: selector(ecid) + ["set-icon-layout", file.path])
        guard result.succeeded else {
            throw DeviceError.commandFailed(message: failureMessage(result))
        }
    }

    // MARK: Helpers

    private func selector(_ ecid: String?) -> [String] {
        guard let ecid, !ecid.isEmpty else {
            return []
        }
        return ["-e", ecid]
    }

    private func runForEnvelope(_ arguments: [String]) async throws -> CfgutilEnvelope {
        let result = try await runner.execute(executable, arguments: arguments)
        do {
            return try CfgutilParser.parseEnvelope(result.standardOutput)
        } catch DeviceError.malformedOutput(let detail) {
            // No JSON at all: report what the process said instead.
            if !result.succeeded {
                throw DeviceError.commandFailed(message: failureMessage(result))
            }
            throw DeviceError.malformedOutput(detail)
        }
    }

    private func failureMessage(_ result: CommandResult) -> String {
        let text = result.standardError.isEmpty ? result.standardOutput : result.standardError
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "the command exited with an error and printed nothing"
        }
        if trimmed.localizedCaseInsensitiveContains("in use") {
            return "\(trimmed) (quit the Apple Configurator app and try again)"
        }
        return trimmed
    }
}
