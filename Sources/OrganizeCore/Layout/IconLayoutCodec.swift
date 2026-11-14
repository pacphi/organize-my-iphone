import Foundation

public enum IconLayoutError: Error, Equatable, Sendable, LocalizedError {
    case notALayout(String)

    public var errorDescription: String? {
        switch self {
        case .notALayout(let reason):
            return "That is not a Home Screen layout: \(reason)."
        }
    }
}

/// Converts between `IconLayout` and the JSON that `cfgutil get-icon-layout` prints
/// and `cfgutil set-icon-layout` accepts.
///
/// The format is an array of arrays:
///
///     [
///       ["dock.app.1", "dock.app.2"],                      // first entry: the dock
///       ["page1.app", ["Folder", "a", "b"]],               // each later entry: one page
///       ["https://example.com", ["Big", ["a"], ["b"]]]     // web clip; multi-page folder
///     ]
///
/// - A string is a bundle identifier, or a web clip when it is a URL.
/// - A folder is an array whose first entry is its name. The rest are either its items
///   (one page) or one array per folder page.
public enum IconLayoutCodec {
    // MARK: Decoding

    public static func decode(_ value: JSONValue) throws -> IconLayout {
        if let object = value.objectValue {
            // `cfgutil --format JSON` wraps results as {"Output": {"<ECID>": <result>}}.
            if let output = object["Output"]?.objectValue {
                for key in output.keys.sorted() where key != "Errors" {
                    if let candidate = output[key], candidate.arrayValue != nil {
                        return try decode(candidate)
                    }
                }
            }
            throw IconLayoutError.notALayout("found an object with no layout inside")
        }

        guard let entries = value.arrayValue else {
            throw IconLayoutError.notALayout("expected an array of pages")
        }
        guard !entries.isEmpty else {
            throw IconLayoutError.notALayout("the layout is empty")
        }

        var groups: [[IconItem]] = []
        for (index, entry) in entries.enumerated() {
            guard let items = entry.arrayValue else {
                throw IconLayoutError.notALayout("entry \(index) is not an array")
            }
            groups.append(items.map { decodeItem($0) })
        }
        return IconLayout(dock: groups[0], pages: Array(groups.dropFirst()))
    }

    public static func decode(data: Data) throws -> IconLayout {
        try decode(text: String(decoding: data, as: UTF8.self))
    }

    /// Decodes layout JSON, tolerating stray text before or after it.
    public static func decode(text: String) throws -> IconLayout {
        guard let value = JSONText.extract(from: text) else {
            throw IconLayoutError.notALayout("no JSON found")
        }
        return try decode(value)
    }

    static func decodeItem(_ value: JSONValue) -> IconItem {
        switch value {
        case .string:
            return decodeLeaf(value)
        case .array(let elements):
            guard let name = elements.first?.stringValue else {
                return .unknown(value)
            }
            var pages: [[IconItem]] = []
            var loose: [IconItem] = []
            for element in elements.dropFirst() {
                if let nested = element.arrayValue {
                    if !loose.isEmpty {
                        pages.append(loose)
                        loose = []
                    }
                    pages.append(nested.map { decodeLeaf($0) })
                } else {
                    loose.append(decodeLeaf(element))
                }
            }
            if !loose.isEmpty {
                pages.append(loose)
            }
            return .folder(IconFolder(name: name, pages: pages))
        default:
            return .unknown(value)
        }
    }

    static func decodeLeaf(_ value: JSONValue) -> IconItem {
        guard let text = value.stringValue else {
            return .unknown(value)
        }
        return isWebClip(text) ? .webClip(text) : .app(text)
    }

    static func isWebClip(_ text: String) -> Bool {
        text.contains("://")
    }

    // MARK: Encoding

    public static func encode(_ layout: IconLayout) -> JSONValue {
        let groups = [layout.dock] + layout.pages
        let encoded = groups.map { (group: [IconItem]) -> JSONValue in
            JSONValue.array(group.map { encodeItem($0) })
        }
        return .array(encoded)
    }

    public static func encodeData(_ layout: IconLayout, pretty: Bool = true) throws -> Data {
        try encode(layout).serialized(pretty: pretty)
    }

    static func encodeItem(_ item: IconItem) -> JSONValue {
        switch item {
        case .app(let bundleID):
            return .string(bundleID)
        case .webClip(let url):
            return .string(url)
        case .unknown(let raw):
            return raw
        case .folder(let folder):
            let pages = folder.pages.filter { !$0.isEmpty }
            var elements: [JSONValue] = [.string(folder.name)]
            if pages.count == 1 {
                elements.append(contentsOf: pages[0].map { encodeItem($0) })
            } else {
                for page in pages {
                    elements.append(.array(page.map { encodeItem($0) }))
                }
            }
            return .array(elements)
        }
    }
}

// Layouts are stored on disk in cfgutil's own format, so a saved file can be fed straight
// back to `cfgutil set-icon-layout` by hand if ever needed.
extension IconLayout: Codable {
    public init(from decoder: any Decoder) throws {
        let value = try JSONValue(from: decoder)
        self = try IconLayoutCodec.decode(value)
    }

    public func encode(to encoder: any Encoder) throws {
        try IconLayoutCodec.encode(self).encode(to: encoder)
    }
}
