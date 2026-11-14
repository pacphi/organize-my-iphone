import Foundation

/// Classifies with rules only: known browsers and Apple apps, high-precision keywords, then
/// App Store genre.
///
/// It needs no model and no network, so it is the default in tests and CI, and the safety net
/// when a language model skips an app or returns something unusable.
///
/// Each result carries a confidence. Known browsers, Apple apps and apps whose store genre settles the
/// matter score high; keyword matches and catch-all genres score low. `TieredClassification`
/// uses that to send only the uncertain apps to a model.
public struct HeuristicClassifier: AppClassifier {
    public let engineName = "heuristic"

    public init() {}

    public func classify(_ apps: [AppRecord], taxonomy: Taxonomy) async throws -> [Classification] {
        apps.map { classifyOne($0, taxonomy: taxonomy) }
    }

    public func classifyOne(_ app: AppRecord, taxonomy: Taxonomy) -> Classification {
        if KnownApps.isKnownBrowser(app.bundleID) {
            if let category = taxonomy.canonicalName(for: KnownApps.browserCategory) {
                return Classification(
                    bundleID: app.bundleID, category: category, confidence: 0.95, source: "heuristic:known-browser")
            }
            // A custom taxonomy with no browser category may have a better home for a browser
            // than "Utilities", so the low confidence leaves the choice to a model when there is one.
            if let category = taxonomy.canonicalName(for: KnownApps.browserFallbackCategory) {
                return Classification(
                    bundleID: app.bundleID, category: category, confidence: 0.5, source: "heuristic:known-browser")
            }
        }

        if let system = KnownApps.system[app.bundleID],
            let category = taxonomy.canonicalName(for: system.category)
        {
            return Classification(
                bundleID: app.bundleID, category: category, confidence: 0.95, source: "heuristic:system-app")
        }

        let words = HeuristicClassifier.words(in: app)
        for rule in KnownApps.keywordRules where !rule.keywords.isDisjoint(with: words) {
            if let category = taxonomy.canonicalName(for: rule.category) {
                return Classification(
                    bundleID: app.bundleID, category: category, confidence: 0.7, source: "heuristic:keyword")
            }
        }

        if let genre = app.storeGenre,
            let mapped = KnownApps.storeGenreCategories[genre],
            let category = taxonomy.canonicalName(for: mapped)
        {
            let confidence = KnownApps.decisiveStoreGenres.contains(genre) ? 0.9 : 0.5
            return Classification(
                bundleID: app.bundleID, category: category, confidence: confidence, source: "heuristic:store-genre")
        }

        // A custom taxonomy may use the App Store's own genre names directly.
        if let genre = app.storeGenre, let category = taxonomy.canonicalName(for: genre) {
            return Classification(
                bundleID: app.bundleID, category: category, confidence: 0.9, source: "heuristic:store-genre")
        }

        return Classification(
            bundleID: app.bundleID, category: taxonomy.fallback, confidence: 0.2, source: "heuristic:fallback")
    }

    /// Lowercased whole words from the app's name and bundle identifier.
    static func words(in app: AppRecord) -> Set<String> {
        let text = "\(app.name) \(app.bundleID)".lowercased()
        let pieces = text.split { character in
            !(character.isLetter || character.isNumber)
        }
        return Set(pieces.map { String($0) })
    }
}
