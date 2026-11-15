import Foundation

/// One app as the organizer sees it: identity from the phone, context from the App Store.
public struct AppRecord: Codable, Hashable, Sendable, Identifiable {
    public var bundleID: String
    public var name: String
    public var version: String?
    /// The App Store's primary genre, when known (for example "Finance").
    public var storeGenre: String?
    /// A short, single-line description used to give a language model context.
    public var summary: String?
    public var seller: String?

    public var id: String { bundleID }

    public init(
        bundleID: String,
        name: String,
        version: String? = nil,
        storeGenre: String? = nil,
        summary: String? = nil,
        seller: String? = nil
    ) {
        self.bundleID = bundleID
        self.name = name
        self.version = version
        self.storeGenre = storeGenre
        self.summary = summary
        self.seller = seller
    }
}

/// What the App Store lookup returns for one bundle identifier.
public struct AppStoreMetadata: Codable, Hashable, Sendable {
    public var bundleID: String
    public var name: String?
    public var primaryGenre: String?
    public var summary: String?
    public var seller: String?
    /// A link to the app's icon on Apple's image server. Absent in caches made before 0.2.
    public var artworkURL: String?

    public init(
        bundleID: String,
        name: String? = nil,
        primaryGenre: String? = nil,
        summary: String? = nil,
        seller: String? = nil,
        artworkURL: String? = nil
    ) {
        self.bundleID = bundleID
        self.name = name
        self.primaryGenre = primaryGenre
        self.summary = summary
        self.seller = seller
        self.artworkURL = artworkURL
    }
}

/// A device attached over USB.
public struct ConnectedDevice: Codable, Hashable, Sendable {
    public var ecid: String
    public var udid: String?
    public var name: String
    public var deviceType: String?

    public init(ecid: String, udid: String? = nil, name: String, deviceType: String? = nil) {
        self.ecid = ecid
        self.udid = udid
        self.name = name
        self.deviceType = deviceType
    }
}

/// Everything read from the phone in one scan.
public struct ScanSnapshot: Codable, Hashable, Sendable {
    public var device: ConnectedDevice
    public var scannedAt: Date
    public var installedApps: [AppRecord]
    public var layout: IconLayout

    public init(device: ConnectedDevice, scannedAt: Date, installedApps: [AppRecord], layout: IconLayout) {
        self.device = device
        self.scannedAt = scannedAt
        self.installedApps = installedApps
        self.layout = layout
    }
}
