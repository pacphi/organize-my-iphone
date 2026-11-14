import Foundation

/// Everything the preview page shows.
public struct PreviewDocument: Sendable {
    public var deviceName: String
    public var generatedAt: Date
    /// Bundle identifier → display name.
    public var names: [String: String]
    /// Bundle identifier → category, used to tint icons.
    public var categories: [String: String]
    public var current: IconLayout
    public var plans: [OrganizationPlan]

    public init(
        deviceName: String,
        generatedAt: Date,
        names: [String: String],
        categories: [String: String],
        current: IconLayout,
        plans: [OrganizationPlan]
    ) {
        self.deviceName = deviceName
        self.generatedAt = generatedAt
        self.names = names
        self.categories = categories
        self.current = current
        self.plans = plans
    }
}

/// Renders a self-contained HTML page comparing the current Home Screen with each proposal.
///
/// The page has no scripts and loads nothing from the network, so it can be opened from disk
/// or attached to a CI run as an artifact.
public enum HTMLPreviewRenderer {
    public static func render(_ document: PreviewDocument, grid: GridSpec = .iPhone) -> String {
        var html: [String] = []
        html.append("<!DOCTYPE html>")
        html.append("<html lang=\"en\"><head><meta charset=\"utf-8\">")
        html.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
        html.append("<title>Home Screen plan for \(escape(document.deviceName))</title>")
        html.append("<style>\(stylesheet(columns: grid.columns))</style>")
        html.append("</head><body>")
        html.append("<h1>Home Screen plan for \(escape(document.deviceName))</h1>")
        html.append("<p class=\"meta\">Generated \(escape(document.generatedAt.formatted(.iso8601))). ")
        html.append("Nothing on the phone changes until you run <code>organize-my-iphone apply</code>.</p>")

        html.append(
            section(
                title: "Current layout",
                note: "\(document.current.pages.count) page(s), \(document.current.folders.count) folder(s)",
                layout: document.current,
                labels: [],
                document: document
            )
        )
        for plan in document.plans {
            let change = LayoutDiff.summarize(from: document.current, to: plan.layout)
            let note =
                "\(plan.layout.pages.count) page(s), \(plan.layout.folders.count) folder(s); "
                + "\(change.moved) of \(change.totalIcons) icons change page or folder"
            html.append(
                section(
                    title: "Proposal: \(plan.scheme.title)",
                    note: note,
                    layout: plan.layout,
                    labels: plan.pageLabels,
                    document: document
                )
            )
        }
        html.append("</body></html>")
        return html.joined(separator: "\n")
    }

    // MARK: Sections

    static func section(
        title: String,
        note: String,
        layout: IconLayout,
        labels: [String],
        document: PreviewDocument
    ) -> String {
        var html: [String] = []
        html.append("<section><h2>\(escape(title))</h2><p class=\"meta\">\(escape(note))</p>")
        html.append("<div class=\"pages\">")
        for (index, page) in layout.pages.enumerated() {
            let label = index < labels.count ? labels[index] : ""
            html.append(phone(title: "Page \(index + 1)", label: label, items: page, document: document))
        }
        html.append(phone(title: "Dock", label: "", items: layout.dock, document: document))
        html.append("</div>")

        let folders = layout.folders
        if !folders.isEmpty {
            html.append("<details><summary>Folder contents (\(folders.count))</summary><ul>")
            for folder in folders {
                let contents = folder.items.map { label(for: $0, document: document) }.joined(separator: ", ")
                html.append("<li><strong>\(escape(folder.name))</strong> (\(folder.items.count)): \(escape(contents))</li>")
            }
            html.append("</ul></details>")
        }
        html.append("</section>")
        return html.joined(separator: "\n")
    }

    static func phone(title: String, label: String, items: [IconItem], document: PreviewDocument) -> String {
        var html: [String] = []
        html.append("<figure class=\"phone\"><figcaption>\(escape(title))")
        if !label.isEmpty {
            html.append("<span>\(escape(label))</span>")
        }
        html.append("</figcaption><div class=\"grid\">")
        for item in items {
            html.append(tile(for: item, document: document))
        }
        html.append("</div></figure>")
        return html.joined()
    }

    static func tile(for item: IconItem, document: PreviewDocument) -> String {
        let name = label(for: item, document: document)
        switch item {
        case .folder(let folder):
            let dots = folder.items.prefix(9).map { nested -> String in
                "<i style=\"background:\(color(for: nested, document: document))\"></i>"
            }
            return "<div class=\"tile\"><div class=\"icon folder\">\(dots.joined())</div>"
                + "<div class=\"name\">\(escape(name))</div></div>"
        case .app, .webClip, .unknown:
            return "<div class=\"tile\"><div class=\"icon\" style=\"background:\(color(for: item, document: document))\">"
                + "\(escape(initials(of: name)))</div><div class=\"name\">\(escape(name))</div></div>"
        }
    }

    // MARK: Helpers

    static func label(for item: IconItem, document: PreviewDocument) -> String {
        switch item {
        case .app(let bundleID):
            return document.names[bundleID] ?? KnownApps.fallbackName(for: bundleID)
        case .webClip(let url):
            return URL(string: url)?.host ?? url
        case .folder(let folder):
            return folder.name
        case .unknown:
            return "Other item"
        }
    }

    static func color(for item: IconItem, document: PreviewDocument) -> String {
        guard case .app(let bundleID) = item else {
            return "hsl(0, 0%, 55%)"
        }
        let category = document.categories[bundleID] ?? "Other"
        return "hsl(\(hue(for: category)), 55%, 45%)"
    }

    /// A stable hue per category. `hashValue` is not used because it changes on every launch.
    static func hue(for text: String) -> Int {
        var total = 7
        for scalar in text.unicodeScalars {
            total = (total &* 31 &+ Int(scalar.value)) % 3600
        }
        return total % 360
    }

    static func initials(of name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        if words.count >= 2, let first = words[0].first, let second = words[1].first {
            return String([first, second]).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    public static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    static func stylesheet(columns: Int) -> String {
        """
        :root { color-scheme: light dark; }
        body { font: 15px/1.45 -apple-system, system-ui, sans-serif; margin: 24px; }
        h1 { font-size: 22px; margin: 0 0 4px; }
        h2 { font-size: 18px; margin: 32px 0 4px; }
        .meta { opacity: .7; margin: 0 0 12px; }
        .pages { display: flex; flex-wrap: wrap; gap: 16px; }
        .phone { margin: 0; width: 248px; border: 1px solid rgba(128,128,128,.4); border-radius: 26px; padding: 14px; }
        .phone figcaption { font-weight: 600; margin-bottom: 10px; }
        .phone figcaption span { display: block; font-weight: 400; font-size: 12px; opacity: .7; }
        .grid { display: grid; grid-template-columns: repeat(\(columns), 1fr); gap: 10px 6px; }
        .tile { text-align: center; min-width: 0; }
        .icon { width: 44px; height: 44px; margin: 0 auto; border-radius: 11px; color: #fff;
                display: flex; align-items: center; justify-content: center; font-weight: 600; font-size: 14px; }
        .icon.folder { background: rgba(128,128,128,.3); display: grid; grid-template-columns: repeat(3, 1fr);
                       gap: 2px; padding: 6px; box-sizing: border-box; }
        .icon.folder i { display: block; border-radius: 3px; aspect-ratio: 1; }
        .name { font-size: 10px; margin-top: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        details { margin-top: 12px; }
        code { font-size: 13px; }
        """
    }
}
