import Foundation

/// Classifies apps with any `TextCompletionModel`, in batches small enough for its context window.
///
/// Whatever the model skips or gets wrong falls back to `HeuristicClassifier`, so every app always
/// receives a category. If the very first batch fails, the error is rethrown: that almost always
/// means the model is unreachable, and the caller should hear about it instead of silently getting
/// rule-based results.
public struct LLMClassifier: AppClassifier {
    public let model: any TextCompletionModel
    public let batchSize: Int
    /// Called before the first batch and after every batch with how many apps are done and
    /// how many there are in total, so a caller can show progress.
    public let onProgress: (@Sendable (_ completed: Int, _ total: Int) -> Void)?
    private let fallback = HeuristicClassifier()

    public init(
        model: any TextCompletionModel,
        batchSize: Int = 25,
        onProgress: (@Sendable (_ completed: Int, _ total: Int) -> Void)? = nil
    ) {
        self.model = model
        self.batchSize = max(1, batchSize)
        self.onProgress = onProgress
    }

    public var engineName: String {
        "llm:\(model.name)"
    }

    public func classify(_ apps: [AppRecord], taxonomy: Taxonomy) async throws -> [Classification] {
        var results: [Classification] = []
        var hasSucceeded = false
        onProgress?(0, apps.count)

        for batch in apps.chunked(into: batchSize) {
            var assignments: [String: String] = [:]
            do {
                let prompt = ClassificationPrompt.build(apps: batch, taxonomy: taxonomy)
                let schema = ClassificationPrompt.schema(taxonomy: taxonomy, count: batch.count)
                let reply = try await model.complete(prompt: prompt, schema: schema)
                assignments = ClassificationResponseParser.parse(reply, apps: batch, taxonomy: taxonomy)
                hasSucceeded = true
            } catch {
                if !hasSucceeded {
                    throw error
                }
            }

            for app in batch {
                if let category = assignments[app.bundleID] {
                    results.append(
                        Classification(bundleID: app.bundleID, category: category, confidence: 0.85, source: engineName)
                    )
                } else {
                    results.append(fallback.classifyOne(app, taxonomy: taxonomy))
                }
            }
            onProgress?(results.count, apps.count)
        }
        return results
    }
}
