import Foundation

/// One bucket of a bucket table, such as "Morning" or "Talk", and the categories that feed it.
public struct Bucket: Hashable, Sendable {
    public var name: String
    public var categories: [String]

    public init(name: String, categories: [String]) {
        self.name = name
        self.categories = categories
    }
}

/// Maps the categories of the standard taxonomy onto a smaller set of buckets. Categories the
/// table does not name (for example from a custom taxonomy) go to `fallback`.
public struct BucketTable: Hashable, Sendable {
    public var buckets: [Bucket]
    public var fallback: String

    public init(buckets: [Bucket], fallback: String) {
        self.buckets = buckets
        self.fallback = fallback
    }

    /// Bucket names in display order, with the fallback last.
    public var names: [String] {
        var result = buckets.map { $0.name }
        if !result.contains(fallback) {
            result.append(fallback)
        }
        return result
    }

    public func bucket(for category: String) -> String {
        let wanted = Taxonomy.normalize(category)
        for bucket in buckets where bucket.categories.contains(where: { Taxonomy.normalize($0) == wanted }) {
            return bucket.name
        }
        return fallback
    }

    /// Category groups sorted into buckets, in bucket order. Each bucket keeps its categories in
    /// the order the groups came in.
    func sort(_ groups: [AppGroup]) -> [(bucket: String, groups: [AppGroup])] {
        var byBucket: [String: [AppGroup]] = [:]
        for group in groups {
            byBucket[bucket(for: group.category), default: []].append(group)
        }
        return names.compactMap { name in
            guard let groups = byBucket[name], !groups.isEmpty else {
                return nil
            }
            return (name, groups)
        }
    }

    // MARK: Built-in tables for the standard taxonomy

    public static let timeOfDay = BucketTable(
        buckets: [
            Bucket(name: "Morning", categories: ["News & Reading", "Health", "Sports", "Lifestyle"]),
            Bucket(
                name: "Work day",
                categories: ["Work", "Productivity", "AI", "Communication", "Browsers", "Finance"]
            ),
            Bucket(
                name: "Evening",
                categories: [
                    "Entertainment", "Games", "Music & Audio", "Social", "Photo & Video", "Shopping", "Food & Drink",
                ]
            ),
            Bucket(name: "Anytime", categories: ["Travel", "Home", "Learning", "Utilities", "Other"]),
        ],
        fallback: "Anytime"
    )

    public static let verbs = BucketTable(
        buckets: [
            Bucket(name: "Talk", categories: ["Communication", "Social"]),
            Bucket(name: "Watch", categories: ["Entertainment"]),
            Bucket(name: "Listen", categories: ["Music & Audio"]),
            Bucket(name: "Make", categories: ["Photo & Video"]),
            Bucket(name: "Buy", categories: ["Shopping", "Food & Drink"]),
            Bucket(name: "Go", categories: ["Travel"]),
            Bucket(name: "Track", categories: ["Health", "Finance", "Sports"]),
            Bucket(name: "Read", categories: ["News & Reading", "Learning"]),
            Bucket(name: "Play", categories: ["Games"]),
            Bucket(name: "Work", categories: ["Work", "Productivity", "AI"]),
            Bucket(name: "Browse", categories: ["Browsers"]),
            Bucket(name: "Tools", categories: ["Utilities", "Home", "Lifestyle", "Other"]),
        ],
        fallback: "Tools"
    )

    public static let places = BucketTable(
        buckets: [
            Bucket(
                name: "Home",
                categories: ["Home", "Entertainment", "Games", "Food & Drink", "Shopping", "Lifestyle"]
            ),
            Bucket(name: "Commute", categories: ["Music & Audio", "News & Reading", "Learning"]),
            Bucket(name: "Office", categories: ["Work", "Productivity", "AI", "Browsers"]),
            Bucket(name: "Travel", categories: ["Travel"]),
            Bucket(name: "Gym", categories: ["Health", "Sports"]),
            Bucket(
                name: "Everywhere",
                categories: ["Communication", "Social", "Finance", "Photo & Video", "Utilities", "Other"]
            ),
        ],
        fallback: "Everywhere"
    )

    public static let lifeAreas = BucketTable(
        buckets: [
            Bucket(name: "Work", categories: ["Work", "Productivity", "AI", "Browsers"]),
            Bucket(name: "Money", categories: ["Finance", "Shopping"]),
            Bucket(name: "Health", categories: ["Health", "Sports", "Food & Drink"]),
            Bucket(name: "Family", categories: ["Communication", "Social", "Home", "Photo & Video"]),
            Bucket(name: "Learning", categories: ["Learning", "News & Reading"]),
            Bucket(name: "Play", categories: ["Games", "Entertainment", "Music & Audio", "Travel"]),
            Bucket(name: "Everyday", categories: ["Lifestyle", "Utilities", "Other"]),
        ],
        fallback: "Everyday"
    )
}
