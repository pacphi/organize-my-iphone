import CoreGraphics
import Foundation
import ImageIO
import OrganizeCore

/// Main icon colors found from App Store artwork, remembered between runs.
public struct StoreIconColors: Codable, Hashable, Sendable {
    /// Bundle identifier → `#RRGGBB`.
    public var colors: [String: String]
    /// Bundle identifiers whose artwork could not be fetched or read.
    public var failed: [String]

    public init(colors: [String: String] = [:], failed: [String] = []) {
        self.colors = colors
        self.failed = failed
    }

    public var parsed: [String: RGBColor] {
        colors.compactMapValues { RGBColor(hex: $0) }
    }
}

/// Downloads app icons from Apple's image server and finds each one's main color.
///
/// Opt-in (`--icon-colors-from-store`). The only requests are for the icon links the App Store
/// lookup returned, and only to Apple's image hosts. The images are read in memory and not kept.
public struct IconColorSampler: Sendable {
    public let http: any HTTPClient
    public let maximumConcurrentRequests: Int
    /// The icon is shrunk to this many pixels square before its colors are counted.
    public let sampleSize: Int

    public init(http: any HTTPClient = URLSessionHTTPClient(), maximumConcurrentRequests: Int = 6, sampleSize: Int = 32)
    {
        self.http = http
        self.maximumConcurrentRequests = max(1, maximumConcurrentRequests)
        self.sampleSize = max(4, sampleSize)
    }

    /// Only Apple's own image hosts are ever contacted.
    public static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else {
            return false
        }
        return host == "mzstatic.com" || host.hasSuffix(".mzstatic.com")
    }

    /// Returns a color per bundle identifier; apps whose artwork failed are absent.
    /// `onProgress` receives (finished, total) as icons come back.
    public func sample(
        artwork: [String: String],
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [String: RGBColor] {
        let jobs = artwork.compactMap { bundleID, link -> (String, URL)? in
            guard let url = URL(string: link), IconColorSampler.isAllowed(url) else {
                return nil
            }
            return (bundleID, url)
        }
        .sorted { $0.0 < $1.0 }
        let total = jobs.count
        let limit = maximumConcurrentRequests

        return await withTaskGroup(of: (String, RGBColor?).self, returning: [String: RGBColor].self) { group in
            var result: [String: RGBColor] = [:]
            var next = 0
            var finished = 0
            while next < min(limit, jobs.count) {
                let job = jobs[next]
                group.addTask { (job.0, await self.color(of: job.1)) }
                next += 1
            }
            while let (bundleID, color) = await group.next() {
                finished += 1
                onProgress?(finished, total)
                if let color {
                    result[bundleID] = color
                }
                if next < jobs.count {
                    let job = jobs[next]
                    group.addTask { (job.0, await self.color(of: job.1)) }
                    next += 1
                }
            }
            return result
        }
    }

    private func color(of url: URL) async -> RGBColor? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let response = try? await http.send(request), response.statusCode == 200 else {
            return nil
        }
        guard let pixels = IconColorSampler.pixels(of: response.body, size: sampleSize) else {
            return nil
        }
        return DominantColor.of(rgba: pixels)
    }

    /// Decodes an image and shrinks it to `size`×`size` RGBA pixels.
    static func pixels(of data: Data, size: Int) -> [UInt8]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size * size * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard
                let context = CGContext(
                    data: raw.baseAddress,
                    width: size,
                    height: size,
                    bitsPerComponent: 8,
                    bytesPerRow: size * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else {
            return nil
        }
        // Undo the premultiplied alpha so pale edges are not mistaken for dark ones.
        var index = 0
        while index + 3 < buffer.count {
            let alpha = Int(buffer[index + 3])
            if alpha > 0 && alpha < 255 {
                for offset in 0..<3 {
                    buffer[index + offset] = UInt8(min(255, Int(buffer[index + offset]) * 255 / alpha))
                }
            }
            index += 4
        }
        return buffer
    }
}
