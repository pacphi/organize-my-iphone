import Foundation

/// One thing that can sit on the Home Screen.
public enum IconItem: Hashable, Sendable {
    /// An app, by bundle identifier.
    case app(String)
    /// A web clip (a bookmark saved to the Home Screen), by URL.
    case webClip(String)
    /// A folder of items.
    case folder(IconFolder)
    /// Anything this tool does not understand. It is kept verbatim so it is never lost.
    case unknown(JSONValue)

    /// A stable key for comparing layouts. Folders have no key of their own; their contents do.
    public var identityKey: String {
        switch self {
        case .app(let bundleID):
            return "app:\(bundleID)"
        case .webClip(let url):
            return "web:\(url)"
        case .folder(let folder):
            return "folder:\(folder.name)"
        case .unknown(let raw):
            let text = (try? raw.serialized()).map { String(decoding: $0, as: UTF8.self) } ?? "?"
            return "raw:\(text)"
        }
    }
}

/// A Home Screen folder. Each inner array is one page inside the folder.
public struct IconFolder: Hashable, Sendable {
    public var name: String
    public var pages: [[IconItem]]

    public init(name: String, pages: [[IconItem]]) {
        self.name = name
        self.pages = pages
    }

    public var items: [IconItem] {
        pages.flatMap { $0 }
    }
}

/// The whole Home Screen: the dock plus every page.
public struct IconLayout: Hashable, Sendable {
    public var dock: [IconItem]
    public var pages: [[IconItem]]

    public init(dock: [IconItem] = [], pages: [[IconItem]] = []) {
        self.dock = dock
        self.pages = pages
    }

    /// Every non-folder item in visual order, with folder contents flattened in place.
    public var flattenedItems: [IconItem] {
        IconLayout.flatten(dock) + pages.flatMap { IconLayout.flatten($0) }
    }

    /// Bundle identifiers of every app, dock first, in visual order.
    public var appBundleIDs: [String] {
        IconLayout.appIDs(in: flattenedItems)
    }

    /// Bundle identifiers of the apps in the dock (including any inside a dock folder).
    public var dockAppBundleIDs: [String] {
        IconLayout.appIDs(in: IconLayout.flatten(dock))
    }

    /// Every folder that sits directly on the dock or on a page.
    public var folders: [IconFolder] {
        (dock + pages.flatMap { $0 }).compactMap { item -> IconFolder? in
            if case .folder(let folder) = item { return folder }
            return nil
        }
    }

    static func flatten(_ items: [IconItem]) -> [IconItem] {
        var result: [IconItem] = []
        for item in items {
            if case .folder(let folder) = item {
                result.append(contentsOf: flatten(folder.items))
            } else {
                result.append(item)
            }
        }
        return result
    }

    static func appIDs(in items: [IconItem]) -> [String] {
        items.compactMap { item -> String? in
            if case .app(let bundleID) = item { return bundleID }
            return nil
        }
    }
}

/// The grid an iPhone Home Screen offers. Values are the stock iPhone layout; override for iPad.
public struct GridSpec: Codable, Hashable, Sendable {
    public var columns: Int
    public var rows: Int
    public var dockCapacity: Int
    public var folderPageCapacity: Int
    public var maximumPages: Int

    public init(
        columns: Int = 4,
        rows: Int = 6,
        dockCapacity: Int = 4,
        folderPageCapacity: Int = 9,
        maximumPages: Int = 15
    ) {
        self.columns = columns
        self.rows = rows
        self.dockCapacity = dockCapacity
        self.folderPageCapacity = folderPageCapacity
        self.maximumPages = maximumPages
    }

    public var pageCapacity: Int {
        columns * rows
    }

    public static let iPhone = GridSpec()
}
