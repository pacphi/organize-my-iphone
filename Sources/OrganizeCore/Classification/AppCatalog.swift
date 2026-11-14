import Foundation

/// Merges what the phone, the App Store and the built-in tables know into one record per app.
public enum AppCatalog {
    /// - Parameters:
    ///   - bundleIDs: The apps to describe, normally every app in the scanned layout.
    ///   - installed: What `cfgutil` reported (user-installed apps only).
    ///   - store: App Store metadata keyed by bundle identifier. May be empty.
    public static func records(
        for bundleIDs: [String],
        installed: [AppRecord],
        store: [String: AppStoreMetadata]
    ) -> [AppRecord] {
        var installedByID: [String: AppRecord] = [:]
        for app in installed {
            installedByID[app.bundleID] = app
        }

        var seen: Set<String> = []
        var records: [AppRecord] = []
        for bundleID in bundleIDs where seen.insert(bundleID).inserted {
            let onDevice = installedByID[bundleID]
            let metadata = store[bundleID]
            let name =
                nonEmpty(onDevice?.name)
                ?? KnownApps.system[bundleID]?.name
                ?? nonEmpty(metadata?.name)
                ?? KnownApps.fallbackName(for: bundleID)
            records.append(
                AppRecord(
                    bundleID: bundleID,
                    name: name,
                    version: onDevice?.version,
                    storeGenre: metadata?.primaryGenre,
                    summary: metadata?.summary,
                    seller: metadata?.seller
                )
            )
        }
        return records
    }

    /// Bundle identifier → display name.
    public static func names(of records: [AppRecord]) -> [String: String] {
        var result: [String: String] = [:]
        for record in records {
            result[record.bundleID] = record.name
        }
        return result
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }
}
