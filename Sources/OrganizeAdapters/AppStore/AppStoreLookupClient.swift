import Foundation
import OrganizeCore

/// Looks apps up in Apple's public iTunes Lookup API to learn their genre and description.
///
/// Only bundle identifiers are sent. Apps that are not on the App Store (enterprise apps,
/// TestFlight builds, some Apple system apps) simply return nothing.
///
/// Built to stay quick and polite on a large phone: many identifiers per request, a few
/// requests at a time, and few requests overall, because the service limits callers to
/// roughly 20 requests a minute.
public struct AppStoreLookupClient: Sendable {
    public let http: any HTTPClient
    public let country: String
    /// Identifiers per request on the first pass.
    public let batchSize: Int
    /// Identifiers per request when asking again about apps the first pass did not return.
    /// Smaller, in case the service ever answers a large request only in part.
    public let retryBatchSize: Int
    /// Requests in flight at once.
    public let maximumConcurrentRequests: Int

    public init(
        http: any HTTPClient = URLSessionHTTPClient(),
        country: String = "us",
        batchSize: Int = 100,
        retryBatchSize: Int = 40,
        maximumConcurrentRequests: Int = 4
    ) {
        self.http = http
        self.country = country
        self.batchSize = max(1, batchSize)
        self.retryBatchSize = max(1, retryBatchSize)
        self.maximumConcurrentRequests = max(1, maximumConcurrentRequests)
    }

    /// Returns metadata keyed by bundle identifier. Missing apps are absent from the result.
    public func lookup(bundleIDs: [String]) async throws -> [String: AppStoreMetadata] {
        var result = try await fetch(bundleIDs, batchSize: batchSize)

        // Ask once more, in smaller requests, about anything that did not come back. Usually
        // that is a handful of apps that are not in the store, so it costs one extra request.
        let missing = bundleIDs.filter { result[$0] == nil }
        if !missing.isEmpty, retryBatchSize < batchSize {
            for (bundleID, metadata) in try await fetch(missing, batchSize: retryBatchSize) {
                result[bundleID] = metadata
            }
        }
        return result
    }

    /// Fetches the identifiers in batches, a few requests at a time.
    private func fetch(_ bundleIDs: [String], batchSize: Int) async throws -> [String: AppStoreMetadata] {
        var batches: [[String]] = []
        var start = 0
        while start < bundleIDs.count {
            let end = min(start + batchSize, bundleIDs.count)
            batches.append(Array(bundleIDs[start..<end]))
            start = end
        }
        let pending = batches
        let limit = maximumConcurrentRequests

        return try await withThrowingTaskGroup(
            of: [AppStoreMetadata].self,
            returning: [String: AppStoreMetadata].self
        ) { group in
            var result: [String: AppStoreMetadata] = [:]
            var next = 0
            while next < min(limit, pending.count) {
                let batch = pending[next]
                group.addTask { try await self.fetchBatch(batch) }
                next += 1
            }
            while let items = try await group.next() {
                for item in items {
                    result[item.bundleID] = item
                }
                if next < pending.count {
                    let batch = pending[next]
                    group.addTask { try await self.fetchBatch(batch) }
                    next += 1
                }
            }
            return result
        }
    }

    private func fetchBatch(_ bundleIDs: [String]) async throws -> [AppStoreMetadata] {
        let request = try AppStoreLookupClient.makeRequest(bundleIDs: bundleIDs, country: country)
        let response = try await http.send(request)
        guard response.statusCode == 200 else {
            throw HTTPError.unexpectedStatus(response.statusCode, service: "The App Store lookup")
        }
        return try AppStoreLookupClient.parse(response.body)
    }

    static func makeRequest(bundleIDs: [String], country: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleIDs.joined(separator: ",")),
            URLQueryItem(name: "country", value: country),
            // Ask for as many results as the service allows, so a large request is not cut short.
            URLQueryItem(name: "limit", value: "200"),
        ]
        guard let url = components.url else {
            throw HTTPError.unreadableResponse(service: "The App Store lookup")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        return request
    }

    static func parse(_ data: Data) throws -> [AppStoreMetadata] {
        let reply: LookupReply
        do {
            reply = try JSONDecoder().decode(LookupReply.self, from: data)
        } catch {
            throw HTTPError.unreadableResponse(service: "The App Store lookup")
        }
        var items: [AppStoreMetadata] = []
        for entry in reply.results {
            guard let bundleID = entry.bundleId, !bundleID.isEmpty else {
                continue
            }
            items.append(
                AppStoreMetadata(
                    bundleID: bundleID,
                    name: entry.trackName,
                    primaryGenre: entry.primaryGenreName,
                    summary: entry.description.map { summarize($0) },
                    seller: entry.sellerName,
                    artworkURL: entry.artworkUrl100 ?? entry.artworkUrl60
                )
            )
        }
        return items
    }

    /// The first part of a store description on one line, short enough to fit many in a prompt.
    static func summarize(_ description: String, limit: Int = 240) -> String {
        let singleLine = description.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
        if singleLine.count <= limit {
            return singleLine
        }
        return String(singleLine.prefix(limit)) + "…"
    }

    private struct LookupReply: Decodable {
        var results: [Entry]

        struct Entry: Decodable {
            var bundleId: String?
            var trackName: String?
            var primaryGenreName: String?
            var description: String?
            var sellerName: String?
            var artworkUrl100: String?
            var artworkUrl60: String?
        }
    }
}
