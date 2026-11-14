import Foundation

/// One bucket apps can be sorted into.
public struct AppCategory: Codable, Hashable, Sendable, Identifiable {
    /// Shown as a folder name on the phone, so keep it short.
    public var name: String
    /// A one-line description that tells a language model what belongs here.
    public var hint: String

    public var id: String { name }

    public init(name: String, hint: String) {
        self.name = name
        self.hint = hint
    }
}

/// The ordered list of categories a plan may use. Order is the order pages and folders appear in.
///
/// The standard taxonomy is a starting point. Pass your own as JSON with `--taxonomy`.
public struct Taxonomy: Codable, Hashable, Sendable {
    public var categories: [AppCategory]
    /// Where an app goes when nothing else fits.
    public var fallback: String

    public init(categories: [AppCategory], fallback: String = "Other") {
        self.categories = categories
        self.fallback = fallback
    }

    private enum CodingKeys: String, CodingKey {
        case categories
        case fallback
    }

    // `fallback` is optional in hand-written taxonomy files.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.categories = try container.decode([AppCategory].self, forKey: .categories)
        self.fallback = try container.decodeIfPresent(String.self, forKey: .fallback) ?? "Other"
    }

    public var names: [String] {
        var result = categories.map { $0.name }
        if !result.contains(fallback) {
            result.append(fallback)
        }
        return result
    }

    /// Returns the taxonomy's own spelling of a category name, ignoring case, spacing and
    /// "&" versus "and". Returns `nil` when the name is not in the taxonomy.
    public func canonicalName(for raw: String) -> String? {
        let wanted = Taxonomy.normalize(raw)
        guard !wanted.isEmpty else {
            return nil
        }
        return names.first { Taxonomy.normalize($0) == wanted }
    }

    /// Position used for ordering. Unknown categories sort after known ones; the fallback is last.
    public func rank(of name: String) -> Int {
        if name == fallback {
            return Int.max
        }
        if let index = categories.firstIndex(where: { $0.name == name }) {
            return index
        }
        return Int.max - 1
    }

    static func normalize(_ text: String) -> String {
        let replaced = text.lowercased().replacingOccurrences(of: "&", with: "and")
        var kept = String.UnicodeScalarView()
        for scalar in replaced.unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            kept.append(scalar)
        }
        return String(kept)
    }

    public static let standard = Taxonomy(
        categories: [
            AppCategory(name: "Communication", hint: "calls, messaging, email, video meetings, contacts"),
            AppCategory(name: "Social", hint: "social networks, communities, dating, forums"),
            AppCategory(
                name: "Browsers",
                hint: "web browsers: Safari, Chrome, Firefox, Edge, Brave, Opera, Vivaldi, DuckDuckGo, Orion, Arc, Tor and Onion browsers"
            ),
            AppCategory(name: "Productivity", hint: "notes, calendars, tasks, documents, files, automation"),
            AppCategory(name: "Work", hint: "business tools, developer tools, admin consoles, CRM, remote access"),
            AppCategory(name: "AI", hint: "AI assistants and chatbots, image or voice generation"),
            AppCategory(name: "Finance", hint: "banking, payments, investing, crypto, budgeting, tax, wallets"),
            AppCategory(name: "Shopping", hint: "stores, marketplaces, deliveries, loyalty and coupon apps"),
            AppCategory(name: "Travel", hint: "maps, navigation, airlines, hotels, ride sharing, transit, parking"),
            AppCategory(name: "Photo & Video", hint: "camera, photo and video editing, galleries, design"),
            AppCategory(name: "Music & Audio", hint: "music, podcasts, audiobooks, radio, instruments"),
            AppCategory(name: "Entertainment", hint: "streaming video, TV, movies, tickets, events"),
            AppCategory(name: "Games", hint: "all games"),
            AppCategory(name: "News & Reading", hint: "news, magazines, books, read-later, RSS"),
            AppCategory(name: "Health", hint: "fitness, workouts, medical, sleep, meditation, nutrition"),
            AppCategory(name: "Food & Drink", hint: "restaurants, food delivery, recipes, coffee, groceries"),
            AppCategory(name: "Home", hint: "smart home, appliances, security cameras, cars, connected devices"),
            AppCategory(name: "Learning", hint: "education, languages, reference, dictionaries, translation"),
            AppCategory(name: "Sports", hint: "scores, leagues, teams, golf, outdoor activity tracking"),
            AppCategory(name: "Lifestyle", hint: "hobbies, journaling, religion, real estate, weather, everyday living"),
            AppCategory(name: "Utilities", hint: "settings, calculators, scanners, VPN, passwords, system tools"),
        ],
        fallback: "Other"
    )
}
