import Foundation

/// Builds the prompt and reply schema for classifying a batch of apps with a language model.
///
/// Local models generate slowly compared with how fast they read, so the reply is kept as
/// small as possible: apps are numbered in the prompt and the model answers with a flat
/// `{"1":"Finance","2":"Games"}` object. That is roughly a quarter of the tokens of a reply
/// that repeats each bundle identifier, and a JSON Schema can force every number to be present.
public enum ClassificationPrompt {
    /// Longest app description included in the prompt, in characters.
    static let summaryLimit = 120

    public static func build(apps: [AppRecord], taxonomy: Taxonomy) -> String {
        var lines: [String] = []
        lines.append("You are organizing the apps on an iPhone Home Screen.")
        lines.append("Assign each numbered app below to exactly one of these categories:")
        lines.append("")
        for category in taxonomy.categories {
            lines.append("- \(category.name): \(category.hint)")
        }
        if !taxonomy.categories.contains(where: { $0.name == taxonomy.fallback }) {
            lines.append("- \(taxonomy.fallback): use only when nothing above fits")
        }
        lines.append("")
        lines.append("Rules:")
        lines.append("- Use the category names exactly as written above.")
        lines.append("- Judge each app by what people mainly use it for, not by who makes it.")
        lines.append("- Answer for every number from 1 to \(apps.count).")
        lines.append("")
        lines.append("Reply with JSON only: the app's number as the key and its category as the value, like this:")
        lines.append(#"{"1":"<category name>","2":"<category name>"}"#)
        lines.append("")
        lines.append("Apps:")
        for (index, app) in apps.enumerated() {
            lines.append("\(index + 1). \(describe(app))")
        }
        return lines.joined(separator: "\n")
    }

    /// A JSON Schema for the reply: one required property per app number, each limited to the
    /// taxonomy's category names. Models that support structured output cannot skip an app
    /// or invent a category.
    public static func schema(taxonomy: Taxonomy, count: Int) -> JSONValue {
        let category: JSONValue = .object([
            "type": .string("string"),
            "enum": .array(taxonomy.names.map { JSONValue.string($0) }),
        ])
        var properties: [String: JSONValue] = [:]
        var required: [JSONValue] = []
        for number in stride(from: 1, through: max(0, count), by: 1) {
            properties[String(number)] = category
            required.append(.string(String(number)))
        }
        return .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required),
            "additionalProperties": .bool(false),
        ])
    }

    static func describe(_ app: AppRecord) -> String {
        var parts = ["\(app.name) (\(app.bundleID))"]
        if let genre = app.storeGenre, !genre.isEmpty {
            parts.append("App Store genre: \(genre)")
        }
        if let summary = app.summary, !summary.isEmpty {
            parts.append(shorten(summary, to: summaryLimit))
        }
        return parts.joined(separator: " | ")
    }

    static func shorten(_ text: String, to limit: Int) -> String {
        if text.count <= limit {
            return text
        }
        return String(text.prefix(max(1, limit - 1))) + "…"
    }
}

/// Reads a model's reply back into bundle identifier → category.
///
/// Models do not always follow instructions, so besides the requested numbered object this
/// accepts an `assignments` array, a bare array, or an object keyed by bundle identifier, and
/// drops anything it cannot tie to an app in the batch and a category in the taxonomy.
public enum ClassificationResponseParser {
    /// - Parameter apps: The batch the reply answers, in the order it was numbered in the prompt.
    public static func parse(_ reply: String, apps: [AppRecord], taxonomy: Taxonomy) -> [String: String] {
        guard let json = JSONText.extract(from: stripCodeFence(reply)) else {
            return [:]
        }

        var pairs: [(key: String, category: String)] = []
        if let entries = json["assignments"]?.arrayValue ?? json.arrayValue {
            for entry in entries {
                if let key = identifier(in: entry), let category = entry["category"]?.stringValue {
                    pairs.append((key: key, category: category))
                }
            }
        } else if let object = json.objectValue {
            for (key, value) in object {
                if let category = value.stringValue {
                    pairs.append((key: key, category: category))
                }
            }
        }

        let bundleIDs = Set(apps.map { $0.bundleID })
        var result: [String: String] = [:]
        for pair in pairs {
            guard let category = taxonomy.canonicalName(for: pair.category) else {
                continue
            }
            let key = pair.key.trimmingCharacters(in: .whitespaces)
            if let number = Int(key) {
                if number >= 1, number <= apps.count {
                    result[apps[number - 1].bundleID] = category
                }
            } else if bundleIDs.contains(key) {
                result[key] = category
            }
        }
        return result
    }

    static func stripCodeFence(_ text: String) -> String {
        text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
    }

    /// The app an array entry refers to: a bundle identifier or the app's number.
    private static func identifier(in entry: JSONValue) -> String? {
        for key in ["bundleID", "bundleId", "bundle_id", "id", "number", "app"] {
            if let text = entry[key]?.stringValue {
                return text
            }
            if let number = entry[key]?.numberValue, let whole = Int(exactly: number) {
                return String(whole)
            }
        }
        return nil
    }
}
