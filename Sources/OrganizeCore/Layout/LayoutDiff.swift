import Foundation

/// Where an icon lives: the dock or a numbered page, optionally inside a folder.
public struct IconLocation: Hashable, Sendable, CustomStringConvertible {
    /// `nil` means the dock. Pages count from 1.
    public var page: Int?
    public var folder: String?

    public init(page: Int?, folder: String? = nil) {
        self.page = page
        self.folder = folder
    }

    public var description: String {
        let base = page.map { "page \($0)" } ?? "dock"
        if let folder {
            return "\(base), folder \"\(folder)\""
        }
        return base
    }
}

/// How much a proposed layout changes the phone.
public struct LayoutChangeSummary: Hashable, Sendable {
    public var totalIcons: Int
    /// Icons whose page or folder changes. Position within a page is not tracked.
    public var moved: Int
    public var unchanged: Int

    public init(totalIcons: Int, moved: Int, unchanged: Int) {
        self.totalIcons = totalIcons
        self.moved = moved
        self.unchanged = unchanged
    }
}

public enum LayoutDiff {
    /// Maps each icon's identity key to its location.
    public static func locations(in layout: IconLayout) -> [String: IconLocation] {
        var result: [String: IconLocation] = [:]
        record(layout.dock, page: nil, into: &result)
        for (index, page) in layout.pages.enumerated() {
            record(page, page: index + 1, into: &result)
        }
        return result
    }

    public static func summarize(from current: IconLayout, to proposed: IconLayout) -> LayoutChangeSummary {
        let before = locations(in: current)
        let after = locations(in: proposed)
        var moved = 0
        var unchanged = 0
        for (key, location) in after {
            if before[key] == location {
                unchanged += 1
            } else {
                moved += 1
            }
        }
        return LayoutChangeSummary(totalIcons: after.count, moved: moved, unchanged: unchanged)
    }

    private static func record(_ items: [IconItem], page: Int?, into result: inout [String: IconLocation]) {
        for item in items {
            if case .folder(let folder) = item {
                for nested in IconLayout.flatten(folder.items) {
                    result[nested.identityKey] = IconLocation(page: page, folder: folder.name)
                }
            } else {
                result[item.identityKey] = IconLocation(page: page, folder: nil)
            }
        }
    }
}
