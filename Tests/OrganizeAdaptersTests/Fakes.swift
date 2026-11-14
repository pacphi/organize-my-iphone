import Foundation
import OrganizeCore

@testable import OrganizeAdapters

/// Replays scripted results and records every command it was asked to run.
actor FakeCommandRunner: CommandRunning {
    struct Call: Equatable, Sendable {
        var executable: String
        var arguments: [String]
    }

    private var results: [CommandResult]
    private(set) var calls: [Call] = []
    /// Contents of any file passed as the last argument, read while the "command" runs.
    private(set) var capturedFiles: [String] = []

    init(results: [CommandResult]) {
        self.results = results
    }

    func execute(_ executable: String, arguments: [String]) async throws -> CommandResult {
        calls.append(Call(executable: executable, arguments: arguments))
        if let last = arguments.last, let contents = try? String(contentsOfFile: last, encoding: .utf8) {
            capturedFiles.append(contents)
        }
        guard !results.isEmpty else {
            return CommandResult(succeeded: false, standardOutput: "", standardError: "no scripted result")
        }
        return results.removeFirst()
    }
}

/// Replays scripted HTTP responses and records every request.
actor FakeHTTPClient: HTTPClient {
    private var responses: [HTTPResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [HTTPResponse]) {
        self.responses = responses
    }

    init(json: String, statusCode: Int = 200) {
        self.responses = [HTTPResponse(body: Data(json.utf8), statusCode: statusCode)]
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            return HTTPResponse(body: Data(), statusCode: 500)
        }
        return responses.removeFirst()
    }
}

/// Runs the fake cfgutil script through a real subprocess, without relying on its executable bit.
struct ScriptRunner: CommandRunning {
    let script: String

    func execute(_ executable: String, arguments: [String]) async throws -> CommandResult {
        try await SubprocessCommandRunner().execute("/bin/bash", arguments: [script] + arguments)
    }
}

enum TestSupport {
    /// A file in Tests/Fixtures, found relative to this source file.
    static func fixture(_ name: String, filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("omi-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static let layout = IconLayout(
        dock: [.app("com.apple.mobilephone")],
        pages: [
            [.app("com.a"), .folder(IconFolder(name: "Money", pages: [[.app("com.b"), .app("com.c")]]))]
        ]
    )

    static let layoutJSON = #"[["com.apple.mobilephone"],["com.a",["Money","com.b","com.c"]]]"#
}
