import Foundation

/// Plain-text summaries for the terminal.
public enum PlanReport {
    public static func summary(of plan: OrganizationPlan, current: IconLayout, names: [String: String]) -> String {
        let change = LayoutDiff.summarize(from: current, to: plan.layout)
        var lines: [String] = []
        lines.append("\(plan.scheme.title) (\(plan.scheme.rawValue))")
        lines.append(
            "  \(plan.layout.pages.count) page(s), \(plan.layout.folders.count) folder(s); "
                + "\(change.moved) of \(change.totalIcons) icons change page or folder"
        )
        for note in plan.notes ?? [] {
            lines.append("  Note: \(note)")
        }
        for group in plan.groups {
            let preview = group.bundleIDs.prefix(4).map { names[$0] ?? $0 }.joined(separator: ", ")
            let more = group.bundleIDs.count > 4 ? ", …" : ""
            lines.append("  \(pad(group.category, to: 16)) \(pad(String(group.bundleIDs.count), to: 3)) \(preview)\(more)")
        }
        return lines.joined(separator: "\n")
    }

    static func pad(_ text: String, to width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }
}
