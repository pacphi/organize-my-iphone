import Foundation

@testable import OrganizeCore

/// A small Home Screen used across the core tests: a full dock, two pages, a one-page folder,
/// a two-page folder and a web clip. 13 app icons in total, 9 of them outside the dock.
enum Fixtures {
    static let layoutJSON = """
        [
          ["com.apple.mobilephone", "com.apple.mobilesafari", "com.apple.MobileSMS", "com.apple.mobilemail"],
          ["com.apple.Maps", "com.spotify.client", ["Money", "com.chase.sig.ios", "com.paypal.PPClient"], "https://example.com/dashboard"],
          ["com.openai.chat", ["Big", ["com.a.one", "com.a.two"], ["com.a.three"]], "com.burbn.instagram"]
        ]
        """

    static var layout: IconLayout {
        IconLayout(
            dock: [
                .app("com.apple.mobilephone"),
                .app("com.apple.mobilesafari"),
                .app("com.apple.MobileSMS"),
                .app("com.apple.mobilemail"),
            ],
            pages: [
                [
                    .app("com.apple.Maps"),
                    .app("com.spotify.client"),
                    .folder(
                        IconFolder(name: "Money", pages: [[.app("com.chase.sig.ios"), .app("com.paypal.PPClient")]])
                    ),
                    .webClip("https://example.com/dashboard"),
                ],
                [
                    .app("com.openai.chat"),
                    .folder(
                        IconFolder(
                            name: "Big",
                            pages: [[.app("com.a.one"), .app("com.a.two")], [.app("com.a.three")]]
                        )
                    ),
                    .app("com.burbn.instagram"),
                ],
            ]
        )
    }

    static let names: [String: String] = [
        "com.apple.Maps": "Maps",
        "com.spotify.client": "Spotify",
        "com.chase.sig.ios": "Chase",
        "com.paypal.PPClient": "PayPal",
        "com.openai.chat": "ChatGPT",
        "com.a.one": "Zeta",
        "com.a.two": "alpha",
        "com.a.three": "Mid",
        "com.burbn.instagram": "Instagram",
    ]

    static let classifications: [String: String] = [
        "com.apple.Maps": "Travel",
        "com.spotify.client": "Music & Audio",
        "com.chase.sig.ios": "Finance",
        "com.paypal.PPClient": "Finance",
        "com.openai.chat": "AI",
        "com.a.one": "Games",
        "com.a.two": "Games",
        "com.a.three": "Games",
        "com.burbn.instagram": "Social",
    ]

    /// Identity keys of everything outside the dock, for "nothing was lost" checks.
    static var nonDockKeys: Set<String> {
        Set(layout.pages.flatMap { IconLayout.flatten($0) }.map { $0.identityKey })
    }

    static func apps(_ count: Int, prefix: String = "com.bulk.app") -> [String] {
        (0..<count).map { "\(prefix)\($0)" }
    }
}

/// A scripted language model that records the prompts it was given.
actor FakeModel: TextCompletionModel {
    nonisolated let name = "fake"
    private var replies: [Result<String, any Error>]
    private(set) var prompts: [String] = []

    init(replies: [Result<String, any Error>]) {
        self.replies = replies
    }

    func complete(prompt: String, schema: JSONValue?) async throws -> String {
        prompts.append(prompt)
        guard !replies.isEmpty else {
            return ""
        }
        return try replies.removeFirst().get()
    }
}

struct FakeFailure: Error {}

/// Collects progress callbacks, which may arrive from any thread.
final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [[Int]] = []

    func record(_ completed: Int, _ total: Int) {
        lock.withLock {
            entries.append([completed, total])
        }
    }

    var all: [[Int]] {
        lock.withLock { entries }
    }
}
