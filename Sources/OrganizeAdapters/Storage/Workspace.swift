import Foundation
import OrganizeCore

/// App Store metadata remembered between runs, so repeat runs make no network calls.
public struct MetadataCache: Codable, Hashable, Sendable {
    public var entries: [String: AppStoreMetadata]
    /// Bundle identifiers the App Store had nothing for.
    public var notFound: [String]

    public init(entries: [String: AppStoreMetadata] = [:], notFound: [String] = []) {
        self.entries = entries
        self.notFound = notFound
    }
}

/// The folder where a run keeps its files.
///
///     <workspace>/
///       scan.json                   what was read from the phone
///       metadata.json               App Store lookups (cache)
///       classification.json         category per app
///       plan-<scheme>.json          one proposal per layout, e.g. plan-folder-board.json
///       preview.html                visual comparison
///       backups/icon-layout-*.json  every layout read from the phone, in cfgutil format
///
/// It defaults to `~/.organize-my-iphone` so the list of apps on your phone never lands in a
/// git repository by accident.
public struct Workspace: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func defaultRoot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        if let custom = environment["OMI_WORKSPACE"], !custom.isEmpty {
            return URL(fileURLWithPath: NSString(string: custom).expandingTildeInPath)
        }
        return home.appendingPathComponent(".organize-my-iphone")
    }

    public var scanURL: URL { root.appendingPathComponent("scan.json") }
    public var metadataURL: URL { root.appendingPathComponent("metadata.json") }
    public var classificationURL: URL { root.appendingPathComponent("classification.json") }
    public var previewURL: URL { root.appendingPathComponent("preview.html") }
    public var backupsDirectory: URL { root.appendingPathComponent("backups") }

    public func planURL(for scheme: OrganizationScheme) -> URL {
        root.appendingPathComponent("plan-\(scheme.rawValue).json")
    }

    /// Creates the workspace folders if they are missing.
    public func prepare() throws {
        try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: JSON documents

    public func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try prepare()
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    public func read<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    public func writeText(_ text: String, to url: URL) throws {
        try prepare()
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    // MARK: Layout backups

    /// Why a backup was taken. Part of the file name, so `restore` can find the right one.
    public enum BackupReason: String, Sendable, CaseIterable {
        case scan
        case beforeApply = "before-apply"
    }

    /// Saves a layout in cfgutil's own format and returns where it went.
    @discardableResult
    public func saveBackup(
        _ layout: IconLayout,
        reason: BackupReason,
        at date: Date,
        timeZone: TimeZone = .current
    ) throws -> URL {
        try prepare()
        let name = "icon-layout-\(Workspace.stamp(date, timeZone: timeZone))-\(reason.rawValue).json"
        let url = backupsDirectory.appendingPathComponent(name)
        try IconLayoutCodec.encodeData(layout).write(to: url, options: .atomic)
        return url
    }

    /// Every backup, oldest first. File names start with a timestamp, so they sort chronologically.
    public func backups(reason: BackupReason? = nil) throws -> [URL] {
        guard exists(backupsDirectory) else {
            return []
        }
        let files = try FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)
        let matching = files.filter { (file: URL) -> Bool in
            let name = file.lastPathComponent
            guard name.hasPrefix("icon-layout-"), name.hasSuffix(".json") else {
                return false
            }
            if let reason {
                return name.hasSuffix("-\(reason.rawValue).json")
            }
            return true
        }
        return matching.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The most recent backup, optionally limited to one reason.
    public func latestBackup(reason: BackupReason? = nil) throws -> URL? {
        try backups(reason: reason).last
    }

    public func loadLayout(from url: URL) throws -> IconLayout {
        try IconLayoutCodec.decode(data: Data(contentsOf: url))
    }

    static func stamp(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        // Milliseconds keep two backups taken in the same second from overwriting each other.
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: date)
    }
}
