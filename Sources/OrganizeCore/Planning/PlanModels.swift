import Foundation

/// The ways a Home Screen can be organized.
public enum OrganizationScheme: String, Codable, Sendable, CaseIterable {
    /// Apps sit loose on pages, clustered by category, one cluster after another.
    case categoryPages = "category-pages"
    /// One named folder per category, gathered on as few pages as possible.
    case folderBoard = "folder-board"
    /// A to Z across pages, or one folder per letter.
    case alphabetical = "alphabetical"
    /// Most-used apps first, least-used at the back.
    case mostUsed = "most-used"
    /// A morning page, a work-day page and an evening page.
    case timeOfDay = "time-of-day"
    /// Folders named for what you do: Talk, Watch, Listen, Make, Buy, Go, Track and so on.
    case verbFolders = "verb-folders"
    /// Pages sorted by each icon's main color.
    case rainbow = "rainbow"
    /// Most-used apps in the bottom rows, where a thumb reaches easily.
    case thumbReach = "thumb-reach"
    /// Pages for places: Home, Commute, Office, Travel and Gym.
    case places = "places"
    /// Newest apps on page 1 for a trial run, apps you no longer use on a Review page.
    case newAndReview = "new-and-review"
    /// One clean page of essentials; everything else in folders on pages you can hide.
    case essentials = "essentials"
    /// Pages for areas of life: Work, Money, Health, Family, Learning and Play.
    case lifeAreas = "life-areas"

    public var title: String {
        switch self {
        case .categoryPages: return "Category pages"
        case .folderBoard: return "Folder board"
        case .alphabetical: return "Alphabetical"
        case .mostUsed: return "Most used"
        case .timeOfDay: return "Time of day"
        case .verbFolders: return "Verb folders"
        case .rainbow: return "Rainbow"
        case .thumbReach: return "Thumb reach"
        case .places: return "Places"
        case .newAndReview: return "New and review"
        case .essentials: return "Essentials"
        case .lifeAreas: return "Life areas"
        }
    }

    /// One sentence on what the layout looks like.
    public var summary: String {
        switch self {
        case .categoryPages:
            return "Apps stay loose on pages, clustered by category."
        case .folderBoard:
            return "One named folder per category, on as few pages as possible."
        case .alphabetical:
            return "A to Z across pages. Add --letter-folders for one folder per letter."
        case .mostUsed:
            return "Your most-used apps on page 1, the least-used at the back."
        case .timeOfDay:
            return "A Morning page (news, health), a Work day page, an Evening page (streaming, games) and Anytime."
        case .verbFolders:
            return "Folders named for what you do: Talk, Watch, Listen, Make, Buy, Go, Track, Read, Play, Work."
        case .rainbow:
            return "Pages sorted by each icon's main color, red through pink, then white, gray and black."
        case .thumbReach:
            return "Like most used, but each full page puts its most-used apps in the bottom rows."
        case .places:
            return "Pages for Home, Commute, Office, Travel, Gym and Everywhere, ready to pair with Focus modes."
        case .newAndReview:
            return "Newest apps on page 1, the rest by category, and apps you no longer use on a Review page."
        case .essentials:
            return "One clean page of essentials. Everything else goes in folders on pages you can hide."
        case .lifeAreas:
            return "Pages for Work, Money, Health, Family, Learning, Play and Everyday."
        }
    }

    /// What the layout needs beyond the scan and the classification, and what it does without it.
    public var dataNote: String? {
        switch self {
        case .mostUsed, .thumbReach, .essentials:
            return "Uses --usage <file> (most-used first). Without it, your current icon order stands in for usage."
        case .newAndReview:
            return "Uses --recent <file> (newest first) and --usage <file>. Without --recent, the apps at the end "
                + "of your current layout are treated as the newest. Without --usage there is no Review page."
        case .rainbow:
            return "Uses --icon-colors <file> plus built-in colors for Apple's apps. Apps with no color go last."
        case .categoryPages, .folderBoard, .alphabetical, .timeOfDay, .verbFolders, .places, .lifeAreas:
            return nil
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
    /// Folder board and other folder layouts: groups with fewer apps than this stay loose.
    public var minimumFolderSize: Int
    /// Name of the catch-all category for anything left unassigned.
    public var fallbackCategory: String
    /// Alphabetical: one folder per letter instead of loose pages.
    public var letterFolders: Bool
    /// Essentials: how many apps go on the essentials page.
    public var essentialsCount: Int
    /// New and review: how many apps count as new. `nil` means one page.
    public var newCount: Int?

    public init(
        grid: GridSpec = .iPhone,
        onePagePerCategory: Bool = false,
        minimumFolderSize: Int = 2,
        fallbackCategory: String = "Other",
        letterFolders: Bool = false,
        essentialsCount: Int = 12,
        newCount: Int? = nil
    ) {
        self.grid = grid
        self.onePagePerCategory = onePagePerCategory
        self.minimumFolderSize = minimumFolderSize
        self.fallbackCategory = fallbackCategory
        self.letterFolders = letterFolders
        self.essentialsCount = essentialsCount
        self.newCount = newCount
    }
}

/// Facts about the apps that some layouts use, beyond their categories. Everything is optional;
/// each planner says what it does when a fact is missing.
public struct PlanContext: Hashable, Sendable {
    /// Bundle identifier → display name.
    public var names: [String: String]
    /// Bundle identifiers, most-used first, from a file the user supplied.
    public var usage: [String]?
    /// Bundle identifiers, newest install first, from a file the user supplied.
    public var recent: [String]?
    /// Bundle identifier → main icon color.
    public var iconColors: [String: RGBColor]

    public init(
        names: [String: String] = [:],
        usage: [String]? = nil,
        recent: [String]? = nil,
        iconColors: [String: RGBColor] = [:]
    ) {
        self.names = names
        self.usage = usage
        self.recent = recent
        self.iconColors = iconColors
    }
}

/// A planner's result: the layout plus a human label for each page.
public struct PlannedLayout: Hashable, Sendable {
    public var layout: IconLayout
    public var pageLabels: [String]
    /// How the planner grouped the apps, when that is not by category (for example by verb).
    public var groups: [AppGroup]?
    /// Plain-language notes about the plan, such as which stand-in data it used.
    public var notes: [String]

    public init(layout: IconLayout, pageLabels: [String], groups: [AppGroup]? = nil, notes: [String] = []) {
        self.layout = layout
        self.pageLabels = pageLabels
        self.groups = groups
        self.notes = notes
    }
}

/// A complete, saved proposal for the phone.
public struct OrganizationPlan: Codable, Hashable, Sendable {
    public var scheme: OrganizationScheme
    public var createdAt: Date
    public var groups: [AppGroup]
    public var pageLabels: [String]
    public var layout: IconLayout
    /// Notes about the plan, such as which stand-in data it used. Absent in older plan files.
    public var notes: [String]?

    public init(
        scheme: OrganizationScheme,
        createdAt: Date,
        groups: [AppGroup],
        pageLabels: [String],
        layout: IconLayout,
        notes: [String]? = nil
    ) {
        self.scheme = scheme
        self.createdAt = createdAt
        self.groups = groups
        self.pageLabels = pageLabels
        self.layout = layout
        self.notes = notes
    }
}

/// Turns grouped apps into a concrete layout. Every planner must keep the dock as it is and
/// place every non-dock icon from `current` exactly once.
public protocol LayoutPlanner: Sendable {
    var scheme: OrganizationScheme { get }
    func plan(current: IconLayout, groups: [AppGroup], context: PlanContext, options: PlanOptions) -> PlannedLayout
}

extension LayoutPlanner {
    /// Plans with no extra facts: no names, usage, install order or icon colors.
    public func plan(current: IconLayout, groups: [AppGroup], options: PlanOptions) -> PlannedLayout {
        plan(current: current, groups: groups, context: PlanContext(), options: options)
    }
}
