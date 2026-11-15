import Foundation

// The ten layouts beyond category pages and folder board. Each keeps the dock and places every
// non-dock icon exactly once, like every planner, and says in `notes` when it had to use
// stand-in data.

/// Rankings the planners use, with the stand-ins when the user gave no file.
enum Signals {
    static let usageStandIn =
        "No --usage file was given, so your current icon order stands in for how much you use each app."
    static let recentStandIn =
        "No --recent file was given, so the apps at the end of your current layout are treated as the newest. "
        + "That is a guess: it holds when new apps were added after your last icon and you have not moved them."

    /// Every app, most-used first. Apps not in the usage file follow in their current order.
    static func usage(_ context: PlanContext, _ input: PlanInput) -> (order: [String], fromFile: Bool) {
        guard let usage = context.usage else {
            return (input.currentOrder, false)
        }
        return (merge(usage, input.currentOrder), true)
    }

    /// Every app, newest first. Without a file, the end of the current layout counts as newest.
    static func recent(_ context: PlanContext, _ input: PlanInput) -> (order: [String], fromFile: Bool) {
        guard let recent = context.recent else {
            return (input.currentOrder.reversed(), false)
        }
        return (merge(recent, input.currentOrder), true)
    }

    /// The listed apps that are on the phone, in list order, then the rest in their given order.
    private static func merge(_ listed: [String], _ all: [String]) -> [String] {
        let present = Set(all)
        var seen: Set<String> = []
        var result: [String] = []
        for bundleID in listed where present.contains(bundleID) && seen.insert(bundleID).inserted {
            result.append(bundleID)
        }
        result.append(contentsOf: all.filter { !seen.contains($0) })
        return result
    }
}

private let extrasTitle = "Web clips & other"

private func extrasSection(_ input: PlanInput) -> [PackSection] {
    input.leftovers.isEmpty
        ? [] : [PackSection(title: extrasTitle, groups: [], extras: input.leftovers, startsNewPage: false)]
}

// MARK: Alphabetical

/// A to Z across pages, or with `letterFolders`, one folder per letter.
public struct AlphabeticalPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.alphabetical

    public init() {}

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        let sorted = Grouping.sorted(input.currentOrder, names: context.names)

        var letters: [String] = []
        var byLetter: [String: [String]] = [:]
        for bundleID in sorted {
            let letter = AlphabeticalPlanner.letter(of: context.names[bundleID] ?? bundleID)
            if byLetter[letter] == nil {
                letters.append(letter)
            }
            byLetter[letter, default: []].append(bundleID)
        }
        // Digits and symbols ("#") go after Z.
        letters.sort { left, right in
            if (left == "#") != (right == "#") {
                return right == "#"
            }
            return left < right
        }
        let letterGroups = letters.map { AppGroup(category: $0, bundleIDs: byLetter[$0] ?? []) }

        if options.letterFolders {
            let folderCapacity = max(1, options.grid.folderPageCapacity)
            var items: [IconItem] = []
            for group in letterGroups {
                let apps = group.bundleIDs.map { IconItem.app($0) }
                if apps.count >= options.minimumFolderSize {
                    items.append(.folder(IconFolder(name: group.category, pages: apps.chunked(into: folderCapacity))))
                } else {
                    items.append(contentsOf: apps)
                }
            }
            let pages = (items + input.leftovers).chunked(into: max(1, options.grid.pageCapacity))
            return PlannedLayout(
                layout: IconLayout(dock: current.dock, pages: pages),
                pageLabels: pages.indices.map { $0 == 0 ? "Letter folders" : "Letter folders (page \($0 + 1))" },
                groups: letterGroups
            )
        }

        let sections =
            letterGroups.map { PackSection(title: $0.category, groups: [$0], startsNewPage: false) }
            + extrasSection(input)
        let packed = SectionPacker.pack(sections, options: options, fill: true)
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: packed.pages),
            pageLabels: packed.labels.map(AlphabeticalPlanner.rangeLabel),
            groups: letterGroups,
            notes: packed.note.map { [$0] } ?? []
        )
    }

    /// The first letter of a name, A to Z with accents removed, or "#" for anything else.
    static func letter(of name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else {
            return "#"
        }
        let folded = String(first).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).uppercased()
        guard folded.count == 1, let scalar = folded.unicodeScalars.first, ("A"..."Z").contains(scalar) else {
            return "#"
        }
        return folded
    }

    /// "A · B · C" becomes "A–C"; anything that is not a letter is listed after it.
    static func rangeLabel(_ titles: [String]) -> String {
        let isLetter = { (title: String) in title.count == 1 && title != "#" }
        let letters = titles.filter(isLetter)
        let others = titles.filter { !isLetter($0) }
        var parts: [String] = []
        if let first = letters.first, let last = letters.last {
            parts.append(first == last ? first : "\(first)–\(last)")
        }
        parts.append(contentsOf: others)
        return parts.joined(separator: " · ")
    }
}

// MARK: Most used and thumb reach

/// Most-used apps on page 1, the least-used at the back.
public struct MostUsedPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.mostUsed

    public init() {}

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        RankedLayout.plan(current: current, groups: groups, context: context, options: options, thumbReach: false)
    }
}

/// Like most used, but every full page puts its most-used apps in the bottom rows, where a thumb
/// reaches without stretching. iOS moves icons up to fill gaps, so a page that is not full keeps
/// plain rank order.
public struct ThumbReachPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.thumbReach

    public init() {}

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        RankedLayout.plan(current: current, groups: groups, context: context, options: options, thumbReach: true)
    }

    /// Reorders a full page of ranked items so rank 1 sits bottom left, the bottom row fills
    /// first, and the least-used of the page sit in the top row.
    static func reach(_ page: [IconItem], grid: GridSpec) -> [IconItem] {
        guard page.count == grid.pageCapacity, grid.columns > 0 else {
            return page
        }
        var result = page
        var rank = 0
        for row in (0..<grid.rows).reversed() {
            for column in 0..<grid.columns {
                result[row * grid.columns + column] = page[rank]
                rank += 1
            }
        }
        return result
    }
}

enum RankedLayout {
    static func plan(
        current: IconLayout,
        groups: [AppGroup],
        context: PlanContext,
        options: PlanOptions,
        thumbReach: Bool
    ) -> PlannedLayout {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        let usage = Signals.usage(context, input)
        let packed = RankedPacker.pack(
            order: usage.order,
            extras: input.leftovers,
            categoryOrder: input.groups.map { $0.category },
            categoryOf: input.categoryOf,
            fallback: options.fallbackCategory,
            options: options
        )
        var pages = packed.pages
        if thumbReach {
            for index in 0..<min(packed.loosePages, pages.count) {
                pages[index] = ThumbReachPlanner.reach(pages[index], grid: options.grid)
            }
        }
        var notes = usage.fromFile ? [] : [Signals.usageStandIn]
        if thumbReach {
            notes.append("On each full page the most-used apps sit in the bottom rows, starting bottom left.")
        }
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: pages),
            pageLabels: packed.labels,
            groups: [AppGroup(category: "By use", bundleIDs: usage.order)],
            notes: notes
        )
    }
}

// MARK: Bucket layouts: time of day, places, life areas, verb folders

extension BucketPagesPlanner {
    /// "Home", "Home", "Gym" becomes "Home", "Home (2)", "Gym".
    static func numberRepeats(_ labels: [String]) -> [String] {
        var result: [String] = []
        var run = 0
        for (index, label) in labels.enumerated() {
            run = index > 0 && labels[index - 1] == label ? run + 1 : 1
            result.append(run > 1 ? "\(label) (\(run))" : label)
        }
        return result
    }
}

/// One page (or more) per bucket of a `BucketTable`, with each bucket's apps clustered by category.
public struct BucketPagesPlanner: LayoutPlanner {
    public let scheme: OrganizationScheme
    public let table: BucketTable

    public init(scheme: OrganizationScheme, table: BucketTable) {
        self.scheme = scheme
        self.table = table
    }

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        let sorted = table.sort(input.groups)
        let sections =
            sorted.map { PackSection(title: $0.bucket, groups: $0.groups, startsNewPage: true) }
            + extrasSection(input)
        let packed = SectionPacker.pack(sections, options: options, fill: false)
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: packed.pages),
            pageLabels: BucketPagesPlanner.numberRepeats(packed.labels.map { $0.joined(separator: " · ") }),
            groups: sorted.map { AppGroup(category: $0.bucket, bundleIDs: $0.groups.flatMap { $0.bundleIDs }) },
            notes: packed.note.map { [$0] } ?? []
        )
    }
}

/// Folders named for what you do with the apps inside.
public struct VerbFoldersPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.verbFolders
    public let table: BucketTable

    public init(table: BucketTable = .verbs) {
        self.table = table
    }

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        let verbGroups = table.sort(input.groups).map { entry in
            AppGroup(category: entry.bucket, bundleIDs: entry.groups.flatMap { $0.bundleIDs })
        }
        var planned = FolderBoardPlanner().plan(
            current: current,
            groups: verbGroups,
            context: context,
            options: options
        )
        planned.pageLabels = planned.pageLabels.indices.map {
            $0 == 0 ? "Verb folders" : "Verb folders (page \($0 + 1))"
        }
        planned.groups = verbGroups
        return planned
    }
}

// MARK: Rainbow

/// Pages sorted by each icon's main color.
public struct RainbowPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.rainbow
    static let noColor = "No color data"

    public init() {}

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        var byBand: [String: [(bundleID: String, hue: Double)]] = [:]
        for bundleID in input.currentOrder {
            if let color = context.iconColors[bundleID] {
                byBand[ColorBand.of(color).rawValue, default: []].append((bundleID, color.hsb.hue))
            } else {
                byBand[RainbowPlanner.noColor, default: []].append((bundleID, 0))
            }
        }

        let order = ColorBand.allCases.map { $0.rawValue } + [RainbowPlanner.noColor]
        let bandGroups: [AppGroup] = order.compactMap { band in
            guard let entries = byBand[band], !entries.isEmpty else {
                return nil
            }
            let sorted = entries.sorted { left, right in
                if left.hue != right.hue {
                    return left.hue < right.hue
                }
                let leftName = (context.names[left.bundleID] ?? left.bundleID).lowercased()
                let rightName = (context.names[right.bundleID] ?? right.bundleID).lowercased()
                return leftName != rightName ? leftName < rightName : left.bundleID < right.bundleID
            }
            return AppGroup(category: band, bundleIDs: sorted.map { $0.bundleID })
        }

        let sections =
            bandGroups.map { PackSection(title: $0.category, groups: [$0], startsNewPage: false) }
            + extrasSection(input)
        let packed = SectionPacker.pack(sections, options: options, fill: true)

        var notes: [String] = packed.note.map { [$0] } ?? []
        if let missing = byBand[RainbowPlanner.noColor], !missing.isEmpty {
            notes.append(
                "\(missing.count) app(s) have no known icon color and come last. "
                    + "List them in an --icon-colors file to place them."
            )
        }
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: packed.pages),
            pageLabels: packed.labels.map { $0.joined(separator: " · ") },
            groups: bandGroups,
            notes: notes
        )
    }
}

// MARK: New and review

/// Newest apps on page 1 for a trial run, everything else by category, and the apps the usage
/// file does not mention on a Review page at the back.
public struct NewAndReviewPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.newAndReview

    public init() {}

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        let capacity = max(1, options.grid.pageCapacity)
        let recent = Signals.recent(context, input)
        let newCount = max(0, options.newCount ?? capacity)
        let newApps = Array(recent.order.prefix(newCount))
        let newSet = Set(newApps)

        var reviewApps: [String] = []
        if let usage = context.usage {
            let used = Set(usage)
            reviewApps = Grouping.sorted(
                input.currentOrder.filter { !used.contains($0) && !newSet.contains($0) },
                names: context.names
            )
        }
        let reviewSet = Set(reviewApps)

        let middle: [AppGroup] = input.groups.compactMap { group in
            let kept = group.bundleIDs.filter { !newSet.contains($0) && !reviewSet.contains($0) }
            return kept.isEmpty ? nil : AppGroup(category: group.category, bundleIDs: kept)
        }

        var sections: [PackSection] = []
        if !newApps.isEmpty {
            sections.append(
                PackSection(
                    title: "New",
                    groups: [AppGroup(category: "New", bundleIDs: newApps)],
                    startsNewPage: true,
                    foldable: false
                )
            )
        }
        for (index, group) in middle.enumerated() {
            sections.append(PackSection(title: group.category, groups: [group], startsNewPage: index == 0))
        }
        sections.append(contentsOf: extrasSection(input))
        if !reviewApps.isEmpty {
            sections.append(
                PackSection(
                    title: "Review",
                    groups: [AppGroup(category: "Review", bundleIDs: reviewApps)],
                    startsNewPage: true
                )
            )
        }
        let packed = SectionPacker.pack(sections, options: options, fill: false)

        var notes: [String] = packed.note.map { [$0] } ?? []
        if !recent.fromFile {
            notes.append(Signals.recentStandIn)
        }
        if context.usage == nil {
            notes.append("No --usage file was given, so there is no Review page.")
        } else if !reviewApps.isEmpty {
            notes.append("The Review page holds \(reviewApps.count) app(s) your usage file does not mention.")
        }
        var reported = [AppGroup(category: "New", bundleIDs: newApps)] + middle
        if !reviewApps.isEmpty {
            reported.append(AppGroup(category: "Review", bundleIDs: reviewApps))
        }
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: packed.pages),
            pageLabels: packed.labels.map { $0.joined(separator: " · ") },
            groups: reported.filter { !$0.bundleIDs.isEmpty },
            notes: notes
        )
    }
}

// MARK: Essentials

/// One clean page of essentials. Everything else goes in category folders on later pages, which
/// you can hide in iOS so only the essentials show. No app is removed from the phone.
public struct EssentialsPlanner: LayoutPlanner {
    public let scheme = OrganizationScheme.essentials

    public init() {}

    public func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions)
        -> PlannedLayout
    {
        let input = PlanInput(current: current, groups: groups, fallbackCategory: options.fallbackCategory)
        let capacity = max(1, options.grid.pageCapacity)
        let folderCapacity = max(1, options.grid.folderPageCapacity)
        let usage = Signals.usage(context, input)
        let count = min(max(1, options.essentialsCount), capacity)
        let essentials = Array(usage.order.prefix(count))
        let essentialSet = Set(essentials)

        var folderNames = FolderNames()
        var folders: [IconItem] = []
        var loose: [IconItem] = []
        var rest: [AppGroup] = []
        for group in input.groups {
            let kept = group.bundleIDs.filter { !essentialSet.contains($0) }
            guard !kept.isEmpty else {
                continue
            }
            rest.append(AppGroup(category: group.category, bundleIDs: kept))
            let apps = kept.map { IconItem.app($0) }
            if apps.count >= options.minimumFolderSize {
                let name = folderNames.unique(group.category)
                folders.append(.folder(IconFolder(name: name, pages: apps.chunked(into: folderCapacity))))
            } else {
                loose.append(contentsOf: apps)
            }
        }

        var pages: [[IconItem]] = []
        var labels: [String] = []
        if !essentials.isEmpty {
            pages.append(essentials.map { IconItem.app($0) })
            labels.append("Essentials")
        }
        for page in (folders + loose + input.leftovers).chunked(into: capacity) {
            pages.append(page)
            labels.append("Everything else (hide this page)")
        }

        var notes: [String] = []
        if !usage.fromFile {
            notes.append(Signals.usageStandIn)
        }
        if pages.count > 1 {
            notes.append(
                "To see only the essentials, hide pages 2 and later on the phone: touch and hold the Home Screen, "
                    + "tap the page dots, and untick them. Every app stays on the phone and in the App Library."
            )
        }
        return PlannedLayout(
            layout: IconLayout(dock: current.dock, pages: pages),
            pageLabels: labels,
            groups: [AppGroup(category: "Essentials", bundleIDs: essentials)] + rest,
            notes: notes
        )
    }
}
