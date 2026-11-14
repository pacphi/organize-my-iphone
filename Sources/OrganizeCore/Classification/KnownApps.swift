import Foundation

/// Built-in knowledge that needs no network and no model.
public enum KnownApps {
    public struct SystemApp: Hashable, Sendable {
        public var name: String
        public var category: String

        public init(name: String, category: String) {
            self.name = name
            self.category = category
        }
    }

    /// Apple's own apps. `cfgutil` lists only user-installed apps, so names for these come from here.
    public static let system: [String: SystemApp] = [
        "com.apple.mobilephone": SystemApp(name: "Phone", category: "Communication"),
        "com.apple.MobileSMS": SystemApp(name: "Messages", category: "Communication"),
        "com.apple.mobilemail": SystemApp(name: "Mail", category: "Communication"),
        "com.apple.facetime": SystemApp(name: "FaceTime", category: "Communication"),
        "com.apple.MobileAddressBook": SystemApp(name: "Contacts", category: "Communication"),
        "com.apple.mobilesafari": SystemApp(name: "Safari", category: browserCategory),
        "com.apple.Preferences": SystemApp(name: "Settings", category: "Utilities"),
        "com.apple.AppStore": SystemApp(name: "App Store", category: "Utilities"),
        "com.apple.mobiletimer": SystemApp(name: "Clock", category: "Utilities"),
        "com.apple.calculator": SystemApp(name: "Calculator", category: "Utilities"),
        "com.apple.findmy": SystemApp(name: "Find My", category: "Utilities"),
        "com.apple.VoiceMemos": SystemApp(name: "Voice Memos", category: "Utilities"),
        "com.apple.compass": SystemApp(name: "Compass", category: "Utilities"),
        "com.apple.measure": SystemApp(name: "Measure", category: "Utilities"),
        "com.apple.Magnifier": SystemApp(name: "Magnifier", category: "Utilities"),
        "com.apple.Passwords": SystemApp(name: "Passwords", category: "Utilities"),
        "com.apple.Bridge": SystemApp(name: "Watch", category: "Utilities"),
        "com.apple.tips": SystemApp(name: "Tips", category: "Utilities"),
        "com.apple.mobilecal": SystemApp(name: "Calendar", category: "Productivity"),
        "com.apple.reminders": SystemApp(name: "Reminders", category: "Productivity"),
        "com.apple.mobilenotes": SystemApp(name: "Notes", category: "Productivity"),
        "com.apple.DocumentsApp": SystemApp(name: "Files", category: "Productivity"),
        "com.apple.shortcuts": SystemApp(name: "Shortcuts", category: "Productivity"),
        "com.apple.freeform": SystemApp(name: "Freeform", category: "Productivity"),
        "com.apple.Pages": SystemApp(name: "Pages", category: "Productivity"),
        "com.apple.Numbers": SystemApp(name: "Numbers", category: "Productivity"),
        "com.apple.Keynote": SystemApp(name: "Keynote", category: "Productivity"),
        "com.apple.camera": SystemApp(name: "Camera", category: "Photo & Video"),
        "com.apple.mobileslideshow": SystemApp(name: "Photos", category: "Photo & Video"),
        "com.apple.iMovie": SystemApp(name: "iMovie", category: "Photo & Video"),
        "com.apple.Maps": SystemApp(name: "Maps", category: "Travel"),
        "com.apple.weather": SystemApp(name: "Weather", category: "Lifestyle"),
        "com.apple.journal": SystemApp(name: "Journal", category: "Lifestyle"),
        "com.apple.Music": SystemApp(name: "Music", category: "Music & Audio"),
        "com.apple.podcasts": SystemApp(name: "Podcasts", category: "Music & Audio"),
        "com.apple.mobilegarageband": SystemApp(name: "GarageBand", category: "Music & Audio"),
        "com.apple.tv": SystemApp(name: "TV", category: "Entertainment"),
        "com.apple.MobileStore": SystemApp(name: "iTunes Store", category: "Entertainment"),
        "com.apple.games": SystemApp(name: "Games", category: "Games"),
        "com.apple.news": SystemApp(name: "News", category: "News & Reading"),
        "com.apple.iBooks": SystemApp(name: "Books", category: "News & Reading"),
        "com.apple.stocks": SystemApp(name: "Stocks", category: "Finance"),
        "com.apple.Passbook": SystemApp(name: "Wallet", category: "Finance"),
        "com.apple.Health": SystemApp(name: "Health", category: "Health"),
        "com.apple.Fitness": SystemApp(name: "Fitness", category: "Health"),
        "com.apple.Home": SystemApp(name: "Home", category: "Home"),
        "com.apple.Translate": SystemApp(name: "Translate", category: "Learning"),
    ]

    /// The standard taxonomy's category for web browsers.
    public static let browserCategory = "Browsers"

    /// Where a browser goes when a custom taxonomy has no browser category.
    public static let browserFallbackCategory = "Utilities"

    /// Web browsers recognised by bundle identifier, lowercased. The App Store files browsers
    /// under "Utilities" or "Productivity", so the genre alone cannot pick them out.
    public static let browserBundleIDs: Set<String> = [
        "com.apple.mobilesafari",
        "com.google.chrome.ios",
        "org.mozilla.ios.firefox",
        "org.mozilla.ios.focus",
        "com.brave.ios.browser",
        "com.microsoft.msedge",
        "com.opera.operatouch",
        "com.duckduckgo.mobile.ios",
    ]

    public static func isKnownBrowser(_ bundleID: String) -> Bool {
        browserBundleIDs.contains(bundleID.lowercased())
    }

    /// App Store primary genres mapped onto the standard taxonomy.
    public static let storeGenreCategories: [String: String] = [
        "Books": "News & Reading",
        "Business": "Work",
        "Developer Tools": "Work",
        "Education": "Learning",
        "Entertainment": "Entertainment",
        "Finance": "Finance",
        "Food & Drink": "Food & Drink",
        "Games": "Games",
        "Graphics & Design": "Photo & Video",
        "Health & Fitness": "Health",
        "Kids": "Learning",
        "Lifestyle": "Lifestyle",
        "Magazines & Newspapers": "News & Reading",
        "Medical": "Health",
        "Music": "Music & Audio",
        "Navigation": "Travel",
        "News": "News & Reading",
        "Photo & Video": "Photo & Video",
        "Productivity": "Productivity",
        "Reference": "Learning",
        "Shopping": "Shopping",
        "Social Networking": "Social",
        "Sports": "Sports",
        "Travel": "Travel",
        "Utilities": "Utilities",
        "Weather": "Lifestyle",
    ]

    /// Store genres that say on their own where an app belongs: a "Finance" app goes in
    /// Finance. The rest ("Productivity", "Utilities", "Lifestyle" and so on) cover too many
    /// kinds of app to settle the question, so those apps are worth a model's judgment.
    public static let decisiveStoreGenres: Set<String> = [
        "Books", "Developer Tools", "Education", "Finance", "Food & Drink", "Games",
        "Health & Fitness", "Magazines & Newspapers", "Medical", "Music", "Navigation", "News",
        "Photo & Video", "Shopping", "Sports", "Travel", "Weather",
    ]

    public struct KeywordRule: Hashable, Sendable {
        public var category: String
        public var keywords: Set<String>

        public init(category: String, keywords: Set<String>) {
            self.category = category
            self.keywords = keywords
        }
    }

    /// High-precision words. A rule fires only when a whole word of the app name or a whole
    /// component of the bundle identifier equals one of these.
    public static let keywordRules: [KeywordRule] = [
        // First, so that a browser from an AI company is still filed as a browser.
        KeywordRule(
            category: browserCategory,
            keywords: [
                "browser", "firefox", "vivaldi", "duckduckgo", "ecosia", "msedge", "onionbrowser",
                "operatouch", "operagx", "operamini",
            ]
        ),
        KeywordRule(
            category: "AI",
            keywords: [
                "chatgpt", "openai", "claude", "anthropic", "gemini", "copilot", "perplexity",
                "grok", "mistral", "deepseek", "ollama",
            ]
        ),
        KeywordRule(
            category: "Communication",
            keywords: [
                "whatsapp", "signal", "telegram", "slack", "zoom", "teams", "messenger", "discord",
                "gmail", "outlook", "skype", "webex",
            ]
        ),
        KeywordRule(
            category: "Finance",
            keywords: ["bank", "banking", "paypal", "venmo", "coinbase", "wallet", "invest", "trading", "tax"]
        ),
        KeywordRule(
            category: "Travel",
            keywords: ["uber", "lyft", "airlines", "airways", "airbnb", "hotels", "transit", "parking", "waze"]
        ),
        KeywordRule(
            category: "Work",
            keywords: ["github", "gitlab", "jira", "terminal", "ssh", "aws", "azure", "salesforce", "hubspot"]
        ),
    ]

    /// A readable name for a bundle identifier nothing else can name: "com.acme.SuperNotes" → "SuperNotes".
    public static func fallbackName(for bundleID: String) -> String {
        let last = bundleID.split(separator: ".").last.map { String($0) } ?? bundleID
        return last.isEmpty ? bundleID : last
    }
}
