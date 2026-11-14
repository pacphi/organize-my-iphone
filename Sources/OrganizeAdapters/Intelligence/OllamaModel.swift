import Foundation
import OrganizeCore

public enum ModelError: Error, Equatable, Sendable, LocalizedError {
    case unavailable(String)
    case emptyReply(model: String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .emptyReply(let model):
            return "The model \(model) returned an empty reply."
        }
    }
}

/// A model served by Ollama on this Mac (or any Ollama-compatible server).
///
/// Requests go to `POST /api/chat` with:
///
/// - `stream: false`, one reply per request.
/// - `think: false`. Many current models reason at length before answering, and Ollama turns
///   that on by default. Sorting apps into categories does not need it, and it multiplies the
///   time per request (measured: about 5,000 generated tokens per batch instead of a few
///   hundred). Models that cannot switch thinking off use their lowest level.
/// - `format` set to a JSON Schema when one is given, so the reply has the requested shape.
/// - `keep_alive`, so the model stays in memory between batches and for a rerun soon after.
public struct OllamaModel: TextCompletionModel {
    public static let defaultBaseURL = URL(string: "http://127.0.0.1:11434")!
    /// How long Ollama keeps the model in memory after each request.
    public static let keepAlive = "15m"
    /// Upper bound on generated tokens per request, as a guard against a runaway reply.
    public static let maximumReplyTokens = 2048

    public let name: String
    public let baseURL: URL
    public let http: any HTTPClient

    public init(name: String, baseURL: URL = OllamaModel.defaultBaseURL, http: any HTTPClient = URLSessionHTTPClient()) {
        self.name = name
        self.baseURL = baseURL
        self.http = http
    }

    public func complete(prompt: String, schema: JSONValue?) async throws -> String {
        let request = try OllamaModel.makeChatRequest(model: name, prompt: prompt, schema: schema, baseURL: baseURL)
        let response = try await http.send(request)
        try OllamaModel.checkStatus(response)
        return try OllamaModel.parseChatReply(response.body, model: name)
    }

    // MARK: Loading

    /// True when the model is already in memory, so the first request will not wait for a load.
    public func isLoaded() async throws -> Bool {
        let running = try await OllamaModel.runningModels(baseURL: baseURL, http: http)
        return running.map { OllamaModel.canonicalName($0) }.contains(OllamaModel.canonicalName(name))
    }

    /// Loads the model into memory without generating anything. Returns once it is ready.
    public func load() async throws {
        let request = try OllamaModel.makeLoadRequest(model: name, baseURL: baseURL)
        let response = try await http.send(request)
        try OllamaModel.checkStatus(response)
    }

    // MARK: Discovering models

    /// Names of the models installed on the server, as `GET /api/tags` lists them.
    public static func installedModels(
        baseURL: URL = OllamaModel.defaultBaseURL,
        http: any HTTPClient = URLSessionHTTPClient()
    ) async throws -> [String] {
        try await modelNames(at: "api/tags", baseURL: baseURL, http: http)
    }

    /// Names of the models currently in memory, as `GET /api/ps` lists them.
    public static func runningModels(
        baseURL: URL = OllamaModel.defaultBaseURL,
        http: any HTTPClient = URLSessionHTTPClient()
    ) async throws -> [String] {
        try await modelNames(at: "api/ps", baseURL: baseURL, http: http)
    }

    /// What a model can do, as `POST /api/show` reports it: "completion", "embedding",
    /// "thinking", "vision" and so on. `nil` when the server does not say.
    public static func capabilities(
        of model: String,
        baseURL: URL = OllamaModel.defaultBaseURL,
        http: any HTTPClient = URLSessionHTTPClient()
    ) async -> [String]? {
        guard let request = try? makeJSONRequest(path: "api/show", body: ["model": .string(model)], baseURL: baseURL, timeout: 10)
        else {
            return nil
        }
        guard let response = try? await http.send(request), response.statusCode == 200 else {
            return nil
        }
        guard let root = try? JSONValue.parse(response.body), let entries = root["capabilities"]?.arrayValue else {
            return nil
        }
        return entries.compactMap { $0.stringValue }
    }

    /// Picks a model that can chat. Embedding models are installed alongside chat models and
    /// cannot classify anything, so the first installed model is not always usable.
    ///
    /// Models already in memory are preferred, because they answer without a load.
    public static func chooseChatModel(
        installed: [String],
        running: [String],
        baseURL: URL = OllamaModel.defaultBaseURL,
        http: any HTTPClient = URLSessionHTTPClient()
    ) async -> String? {
        var seen: Set<String> = []
        var candidates: [String] = []
        for name in running + installed {
            if seen.insert(canonicalName(name)).inserted {
                candidates.append(name)
            }
        }
        for candidate in candidates {
            let reported = await capabilities(of: candidate, baseURL: baseURL, http: http)
            if canChat(name: candidate, capabilities: reported) {
                return candidate
            }
        }
        return nil
    }

    /// Whether a model can answer a chat request, from its reported capabilities when there
    /// are any, otherwise from its name.
    static func canChat(name: String, capabilities: [String]?) -> Bool {
        if let capabilities {
            return capabilities.contains("completion")
        }
        let lowered = name.lowercased()
        let embeddingHints = ["embed", "minilm", "bge-", "/bge", "e5-", "gte-"]
        return !embeddingHints.contains { lowered.contains($0) }
    }

    /// Ollama treats "mistral" and "mistral:latest" as the same model.
    public static func canonicalName(_ name: String) -> String {
        let lastComponent = name.split(separator: "/").last.map { String($0) } ?? name
        return lastComponent.contains(":") ? name : "\(name):latest"
    }

    // MARK: Request and reply shapes

    static func makeChatRequest(model: String, prompt: String, schema: JSONValue?, baseURL: URL) throws -> URLRequest {
        var body: [String: JSONValue] = [
            "model": .string(model),
            "stream": .bool(false),
            "think": .bool(false),
            "keep_alive": .string(keepAlive),
            "messages": .array([
                .object(["role": .string("user"), "content": .string(prompt)])
            ]),
            "options": .object([
                // Temperature 0 keeps classification repeatable from run to run.
                "temperature": .number(0),
                "num_predict": .number(Double(maximumReplyTokens)),
            ]),
        ]
        if let schema {
            body["format"] = schema
        }
        // Large local models can take a while on a cold first request.
        return try makeJSONRequest(path: "api/chat", body: body, baseURL: baseURL, timeout: 600)
    }

    /// A generate request with no prompt makes Ollama load the model and return.
    static func makeLoadRequest(model: String, baseURL: URL) throws -> URLRequest {
        try makeJSONRequest(
            path: "api/generate",
            body: ["model": .string(model), "keep_alive": .string(keepAlive)],
            baseURL: baseURL,
            timeout: 600
        )
    }

    static func makeJSONRequest(
        path: String,
        body: [String: JSONValue],
        baseURL: URL,
        timeout: TimeInterval
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONValue.object(body).serialized()
        request.timeoutInterval = timeout
        return request
    }

    /// Throws for any reply that is not HTTP 200, using Ollama's own explanation when it gives
    /// one (for example an unknown model, or a model that cannot generate).
    static func checkStatus(_ response: HTTPResponse) throws {
        guard response.statusCode != 200 else {
            return
        }
        if let root = try? JSONValue.parse(response.body), let message = root["error"]?.stringValue {
            throw ModelError.unavailable("Ollama reported an error: \(message)")
        }
        throw HTTPError.unexpectedStatus(response.statusCode, service: "Ollama")
    }

    static func parseChatReply(_ data: Data, model: String) throws -> String {
        guard let root = try? JSONValue.parse(data) else {
            throw HTTPError.unreadableResponse(service: "Ollama")
        }
        if let message = root["error"]?.stringValue {
            throw ModelError.unavailable("Ollama reported an error: \(message)")
        }
        guard let content = root["message"]?["content"]?.stringValue, !content.isEmpty else {
            throw ModelError.emptyReply(model: model)
        }
        return content
    }

    /// Reads the `models[].name` list that both `/api/tags` and `/api/ps` return.
    static func parseModelNames(_ data: Data) throws -> [String] {
        guard let root = try? JSONValue.parse(data), let models = root["models"]?.arrayValue else {
            throw HTTPError.unreadableResponse(service: "Ollama")
        }
        var names: [String] = []
        for model in models {
            if let name = model["name"]?.stringValue ?? model["model"]?.stringValue {
                names.append(name)
            }
        }
        return names
    }

    private static func modelNames(at path: String, baseURL: URL, http: any HTTPClient) async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = 5
        let response = try await http.send(request)
        try checkStatus(response)
        return try parseModelNames(response.body)
    }
}
