import Foundation

/// The category chosen for one app, and who chose it.
public struct Classification: Codable, Hashable, Sendable {
    public var bundleID: String
    public var category: String
    /// A rough 0–1 indication of how much to trust the choice.
    public var confidence: Double
    /// The engine or rule that produced it, for example "heuristic:store-genre" or "llm:qwen3".
    public var source: String

    public init(bundleID: String, category: String, confidence: Double, source: String) {
        self.bundleID = bundleID
        self.category = category
        self.confidence = confidence
        self.source = source
    }
}

/// A saved classification run.
public struct ClassificationSet: Codable, Hashable, Sendable {
    public var engine: String
    public var createdAt: Date
    public var items: [Classification]

    public init(engine: String, createdAt: Date, items: [Classification]) {
        self.engine = engine
        self.createdAt = createdAt
        self.items = items
    }

    /// Bundle identifier → category name.
    public var categoriesByBundleID: [String: String] {
        var result: [String: String] = [:]
        for item in items {
            result[item.bundleID] = item.category
        }
        return result
    }
}

/// Anything that can sort apps into the categories of a taxonomy.
public protocol AppClassifier: Sendable {
    var engineName: String { get }
    func classify(_ apps: [AppRecord], taxonomy: Taxonomy) async throws -> [Classification]
}

/// A text-in, text-out language model. Adapters implement this for Ollama, Apple's on-device
/// model, or anything else; the classification logic above it stays the same.
public protocol TextCompletionModel: Sendable {
    var name: String { get }
    /// - Parameter schema: A JSON Schema the reply should follow, for models that support it.
    func complete(prompt: String, schema: JSONValue?) async throws -> String
}
