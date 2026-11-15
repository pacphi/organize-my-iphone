import Foundation

/// Reads the optional files that tell some layouts how you use your apps. Reading the file from
/// disk is the caller's job; this only interprets its text.
///
/// Apps are named by bundle identifier (`com.spotify.client`) or by display name (`Spotify`,
/// ignoring case). An exact bundle identifier wins over a display name.
public enum SignalFiles {
    public struct Ranking: Hashable, Sendable {
        /// Bundle identifiers in file order, each once.
        public var order: [String]
        /// Lines that matched no app on the phone.
        public var unmatched: [String]
    }

    public struct Colors: Hashable, Sendable {
        public var colors: [String: RGBColor]
        /// Entries that matched no app, or whose color could not be read.
        public var unmatched: [String]
    }

    public enum FileError: Error, Equatable, CustomStringConvertible {
        case notAJSONObject

        public var description: String {
            switch self {
            case .notAJSONObject:
                return "expected a JSON object such as {\"com.spotify.client\": \"#1DB954\"}"
            }
        }
    }

    /// A ranking file: one app per line, first line first. Blank lines and lines starting with
    /// `#` are skipped, and a leading "1." or "1)" is ignored, so a numbered list works too.
    public static func parseRanking(_ text: String, apps: [String], names: [String: String]) -> Ranking {
        let resolver = Resolver(apps: apps, names: names)
        var order: [String] = []
        var seen: Set<String> = []
        var unmatched: [String] = []
        for rawLine in text.split(whereSeparator: { $0.isNewline }) {
            let line = stripNumbering(rawLine.trimmingCharacters(in: .whitespaces))
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }
            if let bundleID = resolver.resolve(line) {
                if seen.insert(bundleID).inserted {
                    order.append(bundleID)
                }
            } else {
                unmatched.append(line)
            }
        }
        return Ranking(order: order, unmatched: unmatched)
    }

    /// An icon-colors file: a JSON object from app (bundle identifier or name) to `#RRGGBB`.
    public static func parseColors(_ data: Data, apps: [String], names: [String: String]) throws -> Colors {
        guard let object = try JSONValue.parse(data).objectValue else {
            throw FileError.notAJSONObject
        }
        let resolver = Resolver(apps: apps, names: names)
        var colors: [String: RGBColor] = [:]
        var unmatched: [String] = []
        for key in object.keys.sorted() {
            guard let bundleID = resolver.resolve(key), let hex = object[key]?.stringValue,
                let color = RGBColor(hex: hex)
            else {
                unmatched.append(key)
                continue
            }
            colors[bundleID] = color
        }
        return Colors(colors: colors, unmatched: unmatched)
    }

    /// Built-in colors for Apple's own apps, overridden by anything in `extra`.
    public static func iconColors(merging extra: [String: RGBColor]) -> [String: RGBColor] {
        var result: [String: RGBColor] = [:]
        for (bundleID, hex) in KnownApps.iconColors {
            result[bundleID] = RGBColor(hex: hex)
        }
        result.merge(extra) { _, new in new }
        return result
    }

    static func stripNumbering(_ line: String) -> String {
        var index = line.startIndex
        while index < line.endIndex, line[index].isNumber {
            index = line.index(after: index)
        }
        guard index > line.startIndex, index < line.endIndex, line[index] == "." || line[index] == ")" else {
            return line
        }
        return line[line.index(after: index)...].trimmingCharacters(in: .whitespaces)
    }

    private struct Resolver {
        var bundleIDs: Set<String>
        var byName: [String: String]

        init(apps: [String], names: [String: String]) {
            bundleIDs = Set(apps)
            byName = [:]
            // Sorted so that when two apps share a name the choice is stable.
            for bundleID in apps.sorted() {
                let name = (names[bundleID] ?? KnownApps.system[bundleID]?.name ?? "").lowercased()
                if !name.isEmpty, byName[name] == nil {
                    byName[name] = bundleID
                }
            }
        }

        func resolve(_ text: String) -> String? {
            if bundleIDs.contains(text) {
                return text
            }
            return byName[text.lowercased()]
        }
    }
}
