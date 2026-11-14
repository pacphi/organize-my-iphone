import Foundation

/// Sorts the apps of a layout into ordered category groups.
public enum Grouping {
    /// - Parameters:
    ///   - layout: The current layout. Dock apps are left out; the dock is never reorganized.
    ///   - classifications: Bundle identifier → category name.
    ///   - names: Bundle identifier → display name, used to sort apps within a group.
    public static func groups(
        for layout: IconLayout,
        classifications: [String: String],
        names: [String: String],
        taxonomy: Taxonomy
    ) -> [AppGroup] {
        let dock = Set(layout.dockAppBundleIDs)
        var seen: Set<String> = []
        var buckets: [String: [String]] = [:]

        for bundleID in layout.appBundleIDs where !dock.contains(bundleID) && seen.insert(bundleID).inserted {
            let category: String
            if let raw = classifications[bundleID], !raw.isEmpty {
                category = taxonomy.canonicalName(for: raw) ?? raw
            } else {
                category = taxonomy.fallback
            }
            buckets[category, default: []].append(bundleID)
        }

        let groups = buckets.map { category, bundleIDs in
            AppGroup(category: category, bundleIDs: sorted(bundleIDs, names: names))
        }
        return groups.sorted { left, right in
            let leftRank = taxonomy.rank(of: left.category)
            let rightRank = taxonomy.rank(of: right.category)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return left.category < right.category
        }
    }

    /// Alphabetical by display name, ignoring case; bundle identifier breaks ties.
    static func sorted(_ bundleIDs: [String], names: [String: String]) -> [String] {
        bundleIDs.sorted { left, right in
            let leftName = (names[left] ?? left).lowercased()
            let rightName = (names[right] ?? right).lowercased()
            if leftName != rightName {
                return leftName < rightName
            }
            return left < right
        }
    }
}

/// What a planner has to place, with the guarantees every planner relies on already enforced.
struct PlanInput {
    /// Groups limited to apps that are really on the phone, each app once.
    var groups: [AppGroup]
    /// Non-dock items that are not apps (web clips and anything unrecognized).
    var leftovers: [IconItem]

    init(current: IconLayout, groups: [AppGroup], fallbackCategory: String) {
        let dock = Set(current.dockAppBundleIDs)
        var remaining: [String] = []
        var remainingSet: Set<String> = []
        for bundleID in current.appBundleIDs where !dock.contains(bundleID) {
            if remainingSet.insert(bundleID).inserted {
                remaining.append(bundleID)
            }
        }

        var cleaned: [AppGroup] = []
        var placed: Set<String> = []
        for group in groups {
            var kept: [String] = []
            for bundleID in group.bundleIDs where remainingSet.contains(bundleID) {
                if placed.insert(bundleID).inserted {
                    kept.append(bundleID)
                }
            }
            if !kept.isEmpty {
                cleaned.append(AppGroup(category: group.category, bundleIDs: kept))
            }
        }

        // Anything the caller forgot still gets a home.
        let unplaced = remaining.filter { !placed.contains($0) }
        if !unplaced.isEmpty {
            if let index = cleaned.firstIndex(where: { $0.category == fallbackCategory }) {
                cleaned[index].bundleIDs.append(contentsOf: unplaced)
            } else {
                cleaned.append(AppGroup(category: fallbackCategory, bundleIDs: unplaced))
            }
        }

        var leftovers: [IconItem] = []
        for page in current.pages {
            for item in IconLayout.flatten(page) {
                switch item {
                case .webClip, .unknown:
                    leftovers.append(item)
                case .app, .folder:
                    break
                }
            }
        }

        self.groups = cleaned
        self.leftovers = leftovers
    }
}
