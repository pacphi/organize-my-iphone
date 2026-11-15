import Foundation

/// A titled run of icons for `SectionPacker`: one or more groups of apps plus any extra items.
struct PackSection {
    var title: String
    /// Each group stays together. When pages run out, the packer may turn a group into a folder.
    var groups: [AppGroup]
    /// Items that are never folded, such as web clips.
    var extras: [IconItem] = []
    /// Start this section on a fresh page.
    var startsNewPage: Bool
    /// Whether the packer may fold this section's groups into folders to save pages.
    var foldable: Bool = true
}

/// Lays sections out on pages and keeps the plan inside the iOS page limit.
///
/// When the sections need more pages than iOS allows, the largest group is turned into a
/// folder named after it, then the next largest, until the plan fits. If that is still not
/// enough, sections stop starting on fresh pages.
enum SectionPacker {
    /// - Parameter fill: `true` lets icons flow continuously, splitting a section across pages.
    ///   `false` moves a section that does not fit on the current page to the next one.
    /// `note` says, in plain words, when groups were folded or fresh-page starts were dropped.
    static func pack(_ sections: [PackSection], options: PlanOptions, fill: Bool) -> (
        pages: [[IconItem]], labels: [[String]], note: String?
    ) {
        let maximum = max(1, options.grid.maximumPages)
        var folded: Set<GroupRef> = []
        var honorNewPages = true

        func foldUntilItFits() -> (pages: [[IconItem]], labels: [[String]]) {
            var result = build(sections, folded: folded, honorNewPages: honorNewPages, fill: fill, options: options)
            while result.pages.count > maximum, let next = largestUnfolded(sections, folded: folded) {
                folded.insert(next)
                result = build(sections, folded: folded, honorNewPages: honorNewPages, fill: fill, options: options)
            }
            return result
        }

        var result = foldUntilItFits()
        if result.pages.count > maximum, sections.contains(where: { $0.startsNewPage }) {
            honorNewPages = false
            result = foldUntilItFits()
        }

        var parts: [String] = []
        if !folded.isEmpty {
            let names = folded.sorted { ($0.section, $0.group) < ($1.section, $1.group) }.map { ref in
                sections[ref.section].groups[ref.group].category
            }
            parts.append(
                "To stay within \(maximum) pages, \(names.count) group(s) became folders: "
                    + names.joined(separator: ", ") + "."
            )
        }
        if !honorNewPages {
            parts.append("Groups share pages instead of each starting on a fresh one, to stay within \(maximum) pages.")
        }
        return (result.pages, result.labels, parts.isEmpty ? nil : parts.joined(separator: " "))
    }

    struct GroupRef: Hashable {
        var section: Int
        var group: Int
    }

    private static func largestUnfolded(_ sections: [PackSection], folded: Set<GroupRef>) -> GroupRef? {
        var best: (ref: GroupRef, size: Int)?
        for (sectionIndex, section) in sections.enumerated() where section.foldable {
            for (groupIndex, group) in section.groups.enumerated() where group.bundleIDs.count >= 2 {
                let ref = GroupRef(section: sectionIndex, group: groupIndex)
                if !folded.contains(ref), group.bundleIDs.count > (best?.size ?? 0) {
                    best = (ref, group.bundleIDs.count)
                }
            }
        }
        return best?.ref
    }

    private static func build(
        _ sections: [PackSection],
        folded: Set<GroupRef>,
        honorNewPages: Bool,
        fill: Bool,
        options: PlanOptions
    ) -> (pages: [[IconItem]], labels: [[String]]) {
        let capacity = max(1, options.grid.pageCapacity)
        let folderCapacity = max(1, options.grid.folderPageCapacity)
        var folderNames = FolderNames()
        var pages: [[IconItem]] = []
        var labels: [[String]] = []
        var page: [IconItem] = []
        var titles: [String] = []

        func flush() {
            if !page.isEmpty {
                pages.append(page)
                labels.append(titles)
            }
            page = []
            titles = []
        }
        func note(_ title: String) {
            if !titles.contains(title) {
                titles.append(title)
            }
        }

        for (sectionIndex, section) in sections.enumerated() {
            var folders: [IconItem] = []
            var loose: [IconItem] = []
            for (groupIndex, group) in section.groups.enumerated() {
                let apps = group.bundleIDs.map { IconItem.app($0) }
                if folded.contains(GroupRef(section: sectionIndex, group: groupIndex)) {
                    let name = folderNames.unique(group.category)
                    folders.append(.folder(IconFolder(name: name, pages: apps.chunked(into: folderCapacity))))
                } else {
                    loose.append(contentsOf: apps)
                }
            }
            let items = folders + loose + section.extras
            guard !items.isEmpty else {
                continue
            }
            if honorNewPages && section.startsNewPage {
                flush()
            }
            if fill {
                for item in items {
                    if page.count >= capacity {
                        flush()
                    }
                    page.append(item)
                    note(section.title)
                }
            } else {
                for chunk in items.chunked(into: capacity) {
                    if !page.isEmpty && page.count + chunk.count > capacity {
                        flush()
                    }
                    page.append(contentsOf: chunk)
                    note(section.title)
                }
            }
        }
        flush()
        return (pages, labels)
    }
}

/// Lays out apps in rank order on loose pages. When they need more pages than iOS allows, the
/// lowest-ranked apps go into folders by category on the last pages.
enum RankedPacker {
    struct Result {
        var pages: [[IconItem]]
        var labels: [String]
        /// How many leading pages hold loose apps in rank order.
        var loosePages: Int
    }

    static func pack(
        order: [String],
        extras: [IconItem],
        categoryOrder: [String],
        categoryOf: [String: String],
        fallback: String,
        options: PlanOptions
    ) -> Result {
        let capacity = max(1, options.grid.pageCapacity)
        let folderCapacity = max(1, options.grid.folderPageCapacity)
        let maximum = max(1, options.grid.maximumPages)
        let all = order.map { IconItem.app($0) } + extras

        if pageCount(all.count, capacity) <= maximum {
            let pages = all.chunked(into: capacity)
            return Result(pages: pages, labels: rankLabels(pages.count, capacity: capacity), loosePages: pages.count)
        }

        var best: Result?
        for loose in stride(from: maximum - 1, through: 0, by: -1) {
            let kept = Array(order.prefix(loose * capacity))
            let rest = Array(order.dropFirst(loose * capacity))
            var buckets: [String: [String]] = [:]
            for bundleID in rest {
                buckets[categoryOf[bundleID] ?? fallback, default: []].append(bundleID)
            }
            var names = categoryOrder.filter { buckets[$0] != nil }
            names.append(contentsOf: buckets.keys.filter { !names.contains($0) }.sorted())
            var folderNames = FolderNames()
            let folders = names.map { name in
                IconItem.folder(
                    IconFolder(
                        name: folderNames.unique(name),
                        pages: (buckets[name] ?? []).map { IconItem.app($0) }.chunked(into: folderCapacity)
                    )
                )
            }
            let tail = (folders + extras).chunked(into: capacity)
            let pages = kept.map { IconItem.app($0) }.chunked(into: capacity) + tail
            let labels =
                rankLabels(loose, capacity: capacity)
                + tail.map { _ in "Used least, in folders by category" }
            let result = Result(pages: pages, labels: labels, loosePages: loose)
            best = result
            if pages.count <= maximum {
                return result
            }
        }
        return best ?? Result(pages: [], labels: [], loosePages: 0)
    }

    private static func pageCount(_ items: Int, _ capacity: Int) -> Int {
        (items + capacity - 1) / capacity
    }

    private static func rankLabels(_ count: Int, capacity: Int) -> [String] {
        (0..<count).map { index in
            index == 0 ? "Used most" : "Ranks \(index * capacity + 1)–\((index + 1) * capacity)"
        }
    }
}

/// Hands out folder names that are unique within one layout ("Games", then "Games 2").
struct FolderNames {
    private var used: Set<String> = []

    mutating func unique(_ name: String) -> String {
        var candidate = name
        var number = 2
        while used.contains(candidate) {
            candidate = "\(name) \(number)"
            number += 1
        }
        used.insert(candidate)
        return candidate
    }
}
