import Foundation

/// Scheme 1: apps stay loose on pages, clustered by category.
///
/// By default categories are packed one after another so pages fill up. A category that would
/// not fit on the current page starts a new one, so clusters are split only when they are
/// larger than a whole page. With `onePagePerCategory`, every category starts on a fresh page.
/// When the clusters need more pages than iOS allows, the largest become folders.
public struct CategoryPagesPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.categoryPages

    public init() {}

    public func plan(
        current: IconLayout,
        groups: [AppGroup],
        context: PlanContext,
        options: PlanOptions
    ) -> PlannedLayout {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        var sections = input.groups.map { group in
            PackSection(title: group.category, groups: [group], startsNewPage: options.onePagePerCategory)
        }
        if !input.leftovers.isEmpty {
            sections.append(
                PackSection(
                    title: "Web clips & other",
                    groups: [],
                    extras: input.leftovers,
                    startsNewPage: options.onePagePerCategory
                )
            )
        }
        // On a phone with more apps than 15 pages hold, the biggest categories become folders.
        let packed = SectionPacker.pack(sections, options: options, fill: false)
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: packed.pages),
            pageLabels: packed.labels.map { $0.joined(separator: " · ") },
            notes: packed.note.map { [$0] } ?? []
        )
    }
}

/// Scheme 2: one named folder per category, gathered on as few pages as possible.
///
/// Categories smaller than `minimumFolderSize` are left loose after the folders, so a single
/// app never ends up alone in a folder.
public struct FolderBoardPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.folderBoard

    public init() {}

    public func plan(
        current: IconLayout,
        groups: [AppGroup],
        context: PlanContext,
        options: PlanOptions
    ) -> PlannedLayout {
        let capacity = max(1, options.grid.pageCapacity)
        let folderCapacity = max(1, options.grid.folderPageCapacity)
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)

        var folders: [IconItem] = []
        var loose: [IconItem] = []
        for group in input.groups {
            let apps = group.bundleIDs.map { IconItem.app($0) }
            if apps.count < options.minimumFolderSize {
                loose.append(contentsOf: apps)
            } else {
                folders.append(.folder(IconFolder(name: group.category, pages: apps.chunked(into: folderCapacity))))
            }
        }

        let pages = (folders + loose + input.leftovers).chunked(into: capacity)
        let labels = pages.indices.map { index in
            index == 0 ? "Folders" : "Folders (page \(index + 1))"
        }
        return PlannedLayout(layout: IconLayout(dock: current.dock, pages: pages), pageLabels: labels)
    }
}

/// Builds complete plans from a scan and a classification.
public enum PlanBuilder {
    public static func planner(for scheme: OrganizationScheme) -> any LayoutPlanner {
        switch scheme {
        case .categoryPages:
            return CategoryPagesPlanner()
        case .folderBoard:
            return FolderBoardPlanner()
        case .alphabetical:
            return AlphabeticalPlanner()
        case .mostUsed:
            return MostUsedPlanner()
        case .timeOfDay:
            return BucketPagesPlanner(scheme: .timeOfDay, table: .timeOfDay)
        case .verbFolders:
            return VerbFoldersPlanner()
        case .rainbow:
            return RainbowPlanner()
        case .thumbReach:
            return ThumbReachPlanner()
        case .places:
            return BucketPagesPlanner(scheme: .places, table: .places)
        case .newAndReview:
            return NewAndReviewPlanner()
        case .essentials:
            return EssentialsPlanner()
        case .lifeAreas:
            return BucketPagesPlanner(scheme: .lifeAreas, table: .lifeAreas)
        }
    }

    public static func makePlan(
        scheme: OrganizationScheme,
        current: IconLayout,
        classifications: [String: String],
        names: [String: String],
        taxonomy: Taxonomy = .standard,
        options: PlanOptions = PlanOptions(),
        context: PlanContext = PlanContext(),
        now: Date = Date()
    ) -> OrganizationPlan {
        var options = options
        options.fallbackCategory = taxonomy.fallback
        var context = context
        context.names.merge(names) { existing, _ in existing }
        let groups = Grouping.groups(
            for: current,
            classifications: classifications,
            names: names,
            taxonomy: taxonomy
        )
        let planned = planner(for: scheme).plan(current: current, groups: groups, context: context, options: options)
        return OrganizationPlan(
            scheme: scheme,
            createdAt: now,
            groups: planned.groups?.filter { !$0.bundleIDs.isEmpty } ?? groups,
            pageLabels: planned.pageLabels,
            layout: planned.layout,
            notes: planned.notes.isEmpty ? nil : planned.notes
        )
    }
}
