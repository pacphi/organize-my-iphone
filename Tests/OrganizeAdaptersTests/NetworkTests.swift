import Foundation
import OrganizeCore
import Testing

@testable import OrganizeAdapters

@Suite("App Store lookup")
struct AppStoreLookupTests {
    static let reply = """
        {"resultCount":2,"results":[
          {"bundleId":"com.a","trackName":"Alpha","primaryGenreName":"Finance","sellerName":"Alpha Inc.",
           "description":"Track your spending.\\nSecond line.",
           "artworkUrl100":"https://is1-ssl.mzstatic.com/image/a/100x100bb.jpg"},
          {"trackName":"No bundle identifier"},
          {"bundleId":"com.b","trackName":"Beta","primaryGenreName":"Games"}
        ]}
        """

    @Test func buildsTheLookupRequest() throws {
        let request = try AppStoreLookupClient.makeRequest(bundleIDs: ["com.a", "com.b"], country: "gb")
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "itunes.apple.com")
        #expect(components.path == "/lookup")
        #expect(components.queryItems?.contains(URLQueryItem(name: "bundleId", value: "com.a,com.b")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "country", value: "gb")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "limit", value: "200")) == true)
    }

    @Test func readsGenreAndAOneLineSummary() throws {
        let items = try AppStoreLookupClient.parse(Data(Self.reply.utf8))
        #expect(items.map { $0.bundleID } == ["com.a", "com.b"])
        #expect(items[0].primaryGenre == "Finance")
        #expect(items[0].summary == "Track your spending. Second line.")
        #expect(items[0].seller == "Alpha Inc.")
        #expect(items[1].summary == nil)
        #expect(items[0].artworkURL == "https://is1-ssl.mzstatic.com/image/a/100x100bb.jpg")
        #expect(items[1].artworkURL == nil)
    }

    @Test func longDescriptionsAreCutShort() {
        let summary = AppStoreLookupClient.summarize(String(repeating: "x", count: 500), limit: 10)
        #expect(summary == "xxxxxxxxxx…")
    }

    @Test func looksAppsUpInBatches() async throws {
        let empty = HTTPResponse(body: Data(#"{"resultCount":0,"results":[]}"#.utf8), statusCode: 200)
        let http = FakeHTTPClient(responses: [HTTPResponse(body: Data(Self.reply.utf8), statusCode: 200), empty])
        let client = AppStoreLookupClient(http: http, batchSize: 2)

        let found = try await client.lookup(bundleIDs: ["com.a", "com.b", "com.c"])

        #expect(found.keys.sorted() == ["com.a", "com.b"])
        #expect(await http.requests.count == 2)
    }

    @Test func asksAgainInSmallerRequestsAboutAppsThatDidNotComeBack() async throws {
        let first = HTTPResponse(body: Data(#"{"results":[{"bundleId":"com.a","trackName":"Alpha"}]}"#.utf8), statusCode: 200)
        let second = HTTPResponse(body: Data(#"{"results":[{"bundleId":"com.b","trackName":"Beta"}]}"#.utf8), statusCode: 200)
        let http = FakeHTTPClient(responses: [first, second])
        let client = AppStoreLookupClient(http: http, batchSize: 100, retryBatchSize: 40)

        let found = try await client.lookup(bundleIDs: ["com.a", "com.b", "com.c"])

        #expect(found.keys.sorted() == ["com.a", "com.b"])
        let requests = await http.requests
        #expect(requests.count == 2)
        let retryURL = try #require(requests.last?.url)
        let retryItems = URLComponents(url: retryURL, resolvingAgainstBaseURL: false)?.queryItems
        #expect(retryItems?.contains(URLQueryItem(name: "bundleId", value: "com.b,com.c")) == true)
    }

    @Test func aLargePhoneNeedsOnlyAFewRequests() async throws {
        // 1,000 apps: 10 requests of 100. All found, so there is no second pass.
        let ids = (0..<1000).map { "com.bulk.app\($0)" }
        let pages = stride(from: 0, to: 1000, by: 100).map { start -> HTTPResponse in
            let entries = ids[start..<(start + 100)].map { #"{"bundleId":"\#($0)","primaryGenreName":"Games"}"# }
            return HTTPResponse(body: Data("{\"results\":[\(entries.joined(separator: ","))]}".utf8), statusCode: 200)
        }
        let http = FakeHTTPClient(responses: pages)

        let found = try await AppStoreLookupClient(http: http).lookup(bundleIDs: ids)

        // Requests run concurrently, so which request receives which page is not fixed;
        // between them every page is delivered and every app is found.
        #expect(found.count == 1000)
        #expect(await http.requests.count == 10)
    }

    @Test func anHTTPErrorIsReported() async {
        let client = AppStoreLookupClient(http: FakeHTTPClient(json: "{}", statusCode: 503))
        await #expect(throws: HTTPError.unexpectedStatus(503, service: "The App Store lookup")) {
            try await client.lookup(bundleIDs: ["com.a"])
        }
    }

    @Test func anUnreadableReplyIsReported() {
        #expect(throws: HTTPError.unreadableResponse(service: "The App Store lookup")) {
            try AppStoreLookupClient.parse(Data("not json".utf8))
        }
    }
}

@Suite("Ollama model")
struct OllamaModelTests {
    let baseURL = URL(string: "http://127.0.0.1:11434")!

    @Test func buildsAChatRequestWithAStructuredOutputSchema() throws {
        let schema = JSONValue.object(["type": .string("object")])
        let request = try OllamaModel.makeChatRequest(model: "test-model", prompt: "Sort these", schema: schema, baseURL: baseURL)

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "http://127.0.0.1:11434/api/chat")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try JSONValue.parse(try #require(request.httpBody))
        #expect(body["model"] == .string("test-model"))
        #expect(body["stream"] == .bool(false))
        // Thinking multiplies the time per request and is not needed to pick a category.
        #expect(body["think"] == .bool(false))
        #expect(body["keep_alive"] == .string("15m"))
        #expect(body["options"]?["num_predict"] == .number(2048))
        #expect(body["format"] == schema)
        #expect(body["messages"]?.arrayValue?.first?["content"] == .string("Sort these"))
        #expect(body["options"]?["temperature"] == .number(0))
    }

    @Test func leavesOutTheSchemaWhenThereIsNone() throws {
        let request = try OllamaModel.makeChatRequest(model: "m", prompt: "p", schema: nil, baseURL: baseURL)
        let body = try JSONValue.parse(try #require(request.httpBody))
        #expect(body["format"] == nil)
    }

    @Test func readsTheReplyText() throws {
        let data = Data(#"{"model":"m","message":{"role":"assistant","content":"hello"},"done":true}"#.utf8)
        #expect(try OllamaModel.parseChatReply(data, model: "m") == "hello")
    }

    @Test func reportsServerErrorsAndEmptyReplies() {
        #expect(throws: ModelError.unavailable("Ollama reported an error: model not found")) {
            try OllamaModel.parseChatReply(Data(#"{"error":"model not found"}"#.utf8), model: "m")
        }
        #expect(throws: ModelError.emptyReply(model: "m")) {
            try OllamaModel.parseChatReply(Data(#"{"message":{"content":""}}"#.utf8), model: "m")
        }
    }

    @Test func listsInstalledModels() async throws {
        let http = FakeHTTPClient(json: #"{"models":[{"name":"first:latest"},{"name":"second:14b"}]}"#)
        let models = try await OllamaModel.installedModels(baseURL: baseURL, http: http)
        #expect(models == ["first:latest", "second:14b"])
        #expect(await http.requests.first?.url?.absoluteString == "http://127.0.0.1:11434/api/tags")
    }

    @Test func knowsWhetherTheModelIsAlreadyInMemory() async throws {
        let running = #"{"models":[{"name":"mistral:latest","model":"mistral:latest"}]}"#
        let loaded = OllamaModel(name: "mistral", baseURL: baseURL, http: FakeHTTPClient(json: running))
        #expect(try await loaded.isLoaded())

        let http = FakeHTTPClient(json: running)
        let other = OllamaModel(name: "qwen3:32b", baseURL: baseURL, http: http)
        #expect(try await other.isLoaded() == false)
        #expect(await http.requests.first?.url?.absoluteString == "http://127.0.0.1:11434/api/ps")
    }

    @Test func loadsAModelWithAnEmptyGenerateRequest() async throws {
        let http = FakeHTTPClient(json: #"{"model":"m","done":true,"done_reason":"load"}"#)
        try await OllamaModel(name: "m", baseURL: baseURL, http: http).load()

        let request = try #require(await http.requests.first)
        #expect(request.url?.absoluteString == "http://127.0.0.1:11434/api/generate")
        let body = try JSONValue.parse(try #require(request.httpBody))
        #expect(body == .object(["model": .string("m"), "keep_alive": .string("15m")]))
    }

    @Test func aModelThatCannotGenerateFailsToLoadWithOllamasExplanation() async {
        let http = FakeHTTPClient(json: #"{"error":"\"all-minilm\" does not support generate"}"#, statusCode: 400)
        let model = OllamaModel(name: "all-minilm", baseURL: baseURL, http: http)
        await #expect(throws: ModelError.unavailable(#"Ollama reported an error: "all-minilm" does not support generate"#)) {
            try await model.load()
        }
    }

    @Test func tellsChatModelsFromEmbeddingModels() {
        #expect(OllamaModel.canChat(name: "anything", capabilities: ["completion", "thinking"]))
        #expect(!OllamaModel.canChat(name: "anything", capabilities: ["embedding"]))
        // Older servers do not report capabilities, so the name is the only clue.
        #expect(!OllamaModel.canChat(name: "nomic-embed-text:latest", capabilities: nil))
        #expect(!OllamaModel.canChat(name: "Xenova/all-MiniLM-L6-v2:latest", capabilities: nil))
        #expect(OllamaModel.canChat(name: "mistral:latest", capabilities: nil))
    }

    @Test func choosesAChatModelPreferringOneAlreadyInMemory() async {
        // /api/show is asked about each candidate in turn: the running model first.
        let http = FakeHTTPClient(responses: [
            HTTPResponse(body: Data(#"{"capabilities":["completion","thinking"]}"#.utf8), statusCode: 200)
        ])
        let chosen = await OllamaModel.chooseChatModel(
            installed: ["all-minilm:22m", "mistral:latest", "qwen3:32b"],
            running: ["qwen3:32b"],
            baseURL: baseURL,
            http: http
        )
        #expect(chosen == "qwen3:32b")
        #expect(await http.requests.count == 1)
    }

    @Test func skipsEmbeddingModelsWhenChoosing() async {
        let http = FakeHTTPClient(responses: [
            HTTPResponse(body: Data(#"{"capabilities":["embedding"]}"#.utf8), statusCode: 200),
            HTTPResponse(body: Data(#"{"capabilities":["completion"]}"#.utf8), statusCode: 200),
        ])
        let chosen = await OllamaModel.chooseChatModel(
            installed: ["all-minilm:22m", "mistral:latest"],
            running: [],
            baseURL: baseURL,
            http: http
        )
        #expect(chosen == "mistral:latest")
    }

    @Test func treatsAMissingTagAsLatest() {
        #expect(OllamaModel.canonicalName("mistral") == "mistral:latest")
        #expect(OllamaModel.canonicalName("qwen3:32b") == "qwen3:32b")
        #expect(OllamaModel.canonicalName("hf.co/org/model") == "hf.co/org/model:latest")
        #expect(OllamaModel.canonicalName("hf.co/org/model:Q4") == "hf.co/org/model:Q4")
    }

    @Test func completesThroughTheHTTPClient() async throws {
        let http = FakeHTTPClient(json: #"{"message":{"role":"assistant","content":"{\"assignments\":[]}"}}"#)
        let model = OllamaModel(name: "m", baseURL: baseURL, http: http)
        #expect(try await model.complete(prompt: "p", schema: nil) == #"{"assignments":[]}"#)
    }

    @Test func aFailingServerIsReported() async {
        let model = OllamaModel(name: "m", baseURL: baseURL, http: FakeHTTPClient(json: "{}", statusCode: 500))
        await #expect(throws: HTTPError.unexpectedStatus(500, service: "Ollama")) {
            try await model.complete(prompt: "p", schema: nil)
        }
    }

    @Test func anUnknownModelIsExplainedInOllamasWords() async {
        let http = FakeHTTPClient(json: #"{"error":"model 'nope' not found"}"#, statusCode: 404)
        let model = OllamaModel(name: "nope", baseURL: baseURL, http: http)
        await #expect(throws: ModelError.unavailable("Ollama reported an error: model 'nope' not found")) {
            try await model.complete(prompt: "p", schema: nil)
        }
    }

    /// The classifier and the model adapter working together, with only the network faked.
    @Test func classifiesAppsThroughOllama() async throws {
        let reply = #"{"message":{"role":"assistant","content":"{\"1\":\"Games\"}"}}"#
        let model = OllamaModel(name: "m", baseURL: baseURL, http: FakeHTTPClient(json: reply))
        let classifier = LLMClassifier(model: model)

        let results = try await classifier.classify([AppRecord(bundleID: "com.a", name: "Alpha")], taxonomy: .standard)

        #expect(results == [Classification(bundleID: "com.a", category: "Games", confidence: 0.85, source: "llm:m")])
    }
}
