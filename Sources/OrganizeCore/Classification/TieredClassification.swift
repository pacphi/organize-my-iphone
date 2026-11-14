import Foundation

/// Splits classification into a fast tier and a slow tier.
///
/// A local model reads quickly but writes slowly, so asking it about every app makes the run
/// time grow with the size of the phone. Most apps do not need it: Apple's own apps are known,
/// and a store genre such as "Finance" or "Games" already answers the question. Rules settle
/// those instantly, and only the apps the rules are unsure about go to the model.
///
/// That keeps a large phone inside the time budget (see docs/architecture.md) while the model's
/// judgment is still spent where it changes the outcome.
public enum TieredClassification {
    /// Rule results at or above this confidence are accepted without asking a model.
    public static let defaultThreshold = 0.75

    public struct Split: Hashable, Sendable {
        /// Apps the rules placed with confidence.
        public var settled: [Classification]
        /// Apps that need a model's judgment.
        public var undecided: [AppRecord]

        public init(settled: [Classification], undecided: [AppRecord]) {
            self.settled = settled
            self.undecided = undecided
        }
    }

    public static func split(
        _ apps: [AppRecord],
        taxonomy: Taxonomy,
        threshold: Double = defaultThreshold
    ) -> Split {
        let rules = HeuristicClassifier()
        var settled: [Classification] = []
        var undecided: [AppRecord] = []
        for app in apps {
            let result = rules.classifyOne(app, taxonomy: taxonomy)
            if result.confidence >= threshold {
                settled.append(result)
            } else {
                undecided.append(app)
            }
        }
        return Split(settled: settled, undecided: undecided)
    }

    /// Puts the tiers back together in the order of `apps`. A model's answer wins over a rule's;
    /// an app neither tier answered for gets the rule-based result, so nothing is left out.
    public static func merge(
        order apps: [AppRecord],
        settled: [Classification],
        judged: [Classification],
        taxonomy: Taxonomy
    ) -> [Classification] {
        var byBundleID: [String: Classification] = [:]
        for result in settled {
            byBundleID[result.bundleID] = result
        }
        for result in judged {
            byBundleID[result.bundleID] = result
        }
        let rules = HeuristicClassifier()
        return apps.map { app in
            byBundleID[app.bundleID] ?? rules.classifyOne(app, taxonomy: taxonomy)
        }
    }
}
