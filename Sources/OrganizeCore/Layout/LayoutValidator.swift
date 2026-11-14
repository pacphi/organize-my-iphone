import Foundation

/// A problem found in a proposed layout.
public struct LayoutIssue: Hashable, Sendable, CustomStringConvertible {
    public enum Severity: String, Codable, Sendable {
        case error
        case warning
    }

    public var severity: Severity
    public var message: String

    public init(severity: Severity, message: String) {
        self.severity = severity
        self.message = message
    }

    public var description: String {
        "\(severity.rawValue): \(message)"
    }
}

/// Checks a layout before it is allowed anywhere near a phone.
///
/// The rules come from how iOS behaves: pages and folders have fixed capacity, an icon can be in
/// only one place, and a layout that leaves icons out makes iOS place them wherever it likes.
public enum LayoutValidator {
    public static func validate(
        _ proposed: IconLayout,
        against current: IconLayout? = nil,
        grid: GridSpec = .iPhone
    ) -> [LayoutIssue] {
        var issues: [LayoutIssue] = []

        // Capacity.
        if proposed.dock.count > grid.dockCapacity {
            issues.append(error("The dock holds \(proposed.dock.count) items; the limit is \(grid.dockCapacity)."))
        }
        if proposed.pages.count > grid.maximumPages {
            issues.append(
                error("The plan needs \(proposed.pages.count) pages; iOS allows \(grid.maximumPages).")
            )
        }
        for (index, page) in proposed.pages.enumerated() {
            if page.count > grid.pageCapacity {
                issues.append(
                    error("Page \(index + 1) holds \(page.count) items; the limit is \(grid.pageCapacity).")
                )
            }
            if page.isEmpty {
                issues.append(warning("Page \(index + 1) is empty."))
            }
        }

        // Folders.
        for folder in proposed.folders {
            if folder.items.isEmpty {
                issues.append(error("Folder \"\(folder.name)\" is empty."))
            }
            for (index, page) in folder.pages.enumerated() where page.count > grid.folderPageCapacity {
                issues.append(
                    error(
                        "Folder \"\(folder.name)\" page \(index + 1) holds \(page.count) items; "
                            + "the limit is \(grid.folderPageCapacity)."
                    )
                )
            }
        }

        // Each app or web clip may appear once.
        let keys = identityKeys(of: proposed)
        var seen: Set<String> = []
        var duplicates: [String] = []
        for key in keys where !key.hasPrefix("raw:") {
            if !seen.insert(key).inserted, !duplicates.contains(key) {
                duplicates.append(key)
            }
        }
        if !duplicates.isEmpty {
            issues.append(error("Icons appear more than once: \(list(duplicates))."))
        }

        // Nothing on the phone may be dropped, and nothing may be invented.
        if let current {
            let currentKeys = Set(identityKeys(of: current))
            let proposedKeys = Set(keys)
            let missing = currentKeys.subtracting(proposedKeys).sorted()
            let extra = proposedKeys.subtracting(currentKeys).sorted()
            if !missing.isEmpty {
                issues.append(error("\(missing.count) icon(s) on the phone are missing from the plan: \(list(missing))."))
            }
            if !extra.isEmpty {
                issues.append(error("\(extra.count) icon(s) in the plan are not on the phone: \(list(extra))."))
            }
        }

        return issues
    }

    public static func hasErrors(_ issues: [LayoutIssue]) -> Bool {
        issues.contains { $0.severity == .error }
    }

    static func identityKeys(of layout: IconLayout) -> [String] {
        layout.flattenedItems.map { $0.identityKey }
    }

    private static func error(_ message: String) -> LayoutIssue {
        LayoutIssue(severity: .error, message: message)
    }

    private static func warning(_ message: String) -> LayoutIssue {
        LayoutIssue(severity: .warning, message: message)
    }

    private static func list(_ keys: [String], limit: Int = 8) -> String {
        let names = keys.prefix(limit).map { key -> String in
            if let separator = key.firstIndex(of: ":") {
                return String(key[key.index(after: separator)...])
            }
            return key
        }
        let suffix = keys.count > limit ? ", and \(keys.count - limit) more" : ""
        return names.joined(separator: ", ") + suffix
    }
}
