import CoreGraphics
import Foundation
import ImageIO
import OrganizeCore
import Testing
import UniformTypeIdentifiers

@testable import OrganizeAdapters

@Suite("Icon colors from App Store artwork")
struct IconColorSamplerTests {
    /// A square PNG filled with one color, with an optional smaller square of another color.
    static func png(fill: RGBColor, mark: RGBColor? = nil, size: Int = 40) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(red: fill.red, green: fill.green, blue: fill.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        if let mark {
            context.setFillColor(red: mark.red, green: mark.green, blue: mark.blue, alpha: 1)
            context.fill(CGRect(x: size / 4, y: size / 4, width: size / 3, height: size / 3))
        }
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func onlyApplesImageHostsAreContacted() {
        #expect(IconColorSampler.isAllowed(URL(string: "https://is1-ssl.mzstatic.com/image/x.jpg")!))
        #expect(!IconColorSampler.isAllowed(URL(string: "http://is1-ssl.mzstatic.com/image/x.jpg")!))
        #expect(!IconColorSampler.isAllowed(URL(string: "https://example.com/x.jpg")!))
        #expect(!IconColorSampler.isAllowed(URL(string: "https://mzstatic.com.example.com/x.jpg")!))
    }

    @Test func findsTheMainColorOfAnIcon() async throws {
        let blue = try Self.png(fill: RGBColor(hex: "#1E88E5")!, mark: RGBColor(hex: "#FFFFFF")!)
        let red = try Self.png(fill: RGBColor(hex: "#FF3B30")!)
        let http = FakeHTTPClient(responses: [
            HTTPResponse(body: blue, statusCode: 200),
            HTTPResponse(body: Data("not an image".utf8), statusCode: 200),
            HTTPResponse(body: red, statusCode: 200),
        ])
        // Requests go out in bundle identifier order: com.a, com.b, com.c, then the bad link is skipped.
        let colors = await IconColorSampler(http: http, maximumConcurrentRequests: 1).sample(
            artwork: [
                "com.a": "https://is1-ssl.mzstatic.com/a.png",
                "com.b": "https://is1-ssl.mzstatic.com/b.png",
                "com.c": "https://is1-ssl.mzstatic.com/c.png",
                "com.d": "https://example.com/d.png",
            ]
        )
        #expect(colors["com.a"].map(ColorBand.of) == .blue)
        #expect(colors["com.b"] == nil)
        #expect(colors["com.c"].map(ColorBand.of) == .red)
        #expect(colors["com.d"] == nil)
        let hosts = await http.requests.compactMap { $0.url?.host }
        #expect(hosts == ["is1-ssl.mzstatic.com", "is1-ssl.mzstatic.com", "is1-ssl.mzstatic.com"])
    }

    @Test func storeColorsSurviveATripThroughJSON() throws {
        let colors = StoreIconColors(colors: ["com.a": "#1E88E5"], failed: ["com.b"])
        let decoded = try JSONDecoder().decode(StoreIconColors.self, from: JSONEncoder().encode(colors))
        #expect(decoded == colors)
        #expect(decoded.parsed["com.a"]?.hex == "#1E88E5")
    }
}
