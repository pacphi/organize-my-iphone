import Foundation

/// The ways a Home Screen can be organized.
public enum OrganizationScheme: String, Codable, Sendable, CaseIterable {
    /// Apps sit loose on pages, clustered by category, one cluster after another.
    case categoryPages = "category-pages"
    /// One named folder per category, gathered on as few pages as possible.
    case folderBoard = "folder-board"

    public var title: String {
        switch self {
        case .categoryPages:
            return "Category pages"
        case .folderBoard:
            return "Folder board"
        }
    }
}

/// The apps that belong to one category, already in display order.
public struct AppGroup: Codable, Hashable, Sendable {
    public var category: String
    public var bundleIDs: [String]

    public init(category: String, bundleIDs: [String]) {
        self.category = category
        self.bundleIDs = bundleIDs
    }
}

/// Knobs for the planners.
public struct PlanOptions: Codable, Hashable, Sendable {
    public var grid: GridSpec
    /// Category pages: start every category on a fresh page instead of packing pages full.
    public var onePagePerCategory: Bool
    /// Folder board: categories with fewer apps than this stay loose instead of getting a folder.
    public var minimumFolderSize: Int
    /// Name of the catch-all category for anything left unassigned.
    public var fallbackCategory: String

    public init(
        grid: GridSpec = .iPhone,
        onePagePerCategory: Bool = false,
        minimumFolderSize: Int = 2,
        fallbackCategory: String = "Other"
    ) {
        self.grid = grid
        self.onePagePerCategory = onePagePerCategory
        self.minimumFolderSize = minimumFolderSize
        self.fallbackCategory = fallbackCategory
    }
}

/// A planner's result: the layout plus a human label for each page.
public struct PlannedLayout: Hashable, Sendable {
    public var layout: IconLayout
    public var pageLabels: [String]

    public init(layout: IconLayout, pageLabels: [String]) {
        self.layout = layout
        self.pageLabels = pageLabels
    }
}

/// A complete, saved proposal for the phone.
public struct OrganizationPlan: Codable, Hashable, Sendable {
    public var scheme: OrganizationScheme
    public var createdAt: Date
    public var groups: [AppGroup]
    public var pageLabels: [String]
    public var layout: IconLayout

    public init(
        scheme: OrganizationScheme,
        createdAt: Date,
        groups: [AppGroup],
        pageLabels: [String],
        layout: IconLayout
    ) {
        self.scheme = scheme
        self.createdAt = createdAt
        self.groups = groups
        self.pageLabels = pageLabels
        self.layout = layout
    }
}

/// Turns grouped apps into a concrete layout. Every planner must keep the dock as it is and
/// place every non-dock icon from `current` exactly once.
public protocol LayoutPlanner: Sendable {
    var scheme: OrganizationScheme { get }
    func plan(current: IconLayout, groups: [AppGroup], options: PlanOptions) -> PlannedLayout
}
