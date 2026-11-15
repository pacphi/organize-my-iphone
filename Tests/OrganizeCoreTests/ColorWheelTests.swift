import Foundation
import Testing

@testable import OrganizeCore

@Suite("Color wheel")
struct ColorWheelTests {
    private func pixels(_ colors: [(RGBColor, Int)], transparent: Int = 0) -> [UInt8] {
        var result: [UInt8] = []
        for (color, count) in colors {
            for _ in 0..<count {
                result += [
                    UInt8(color.red * 255), UInt8(color.green * 255), UInt8(color.blue * 255), 255,
                ]
            }
        }
        for _ in 0..<transparent {
            result += [255, 0, 0, 0]
        }
        return result
    }

    @Test func theLargestSliceOfTheWheelWins() {
        let blue = RGBColor(hex: "#1E88E5")!
        let white = RGBColor(hex: "#FFFFFF")!
        let found = DominantColor.of(rgba: pixels([(blue, 60), (white, 40)], transparent: 500))
        #expect(found.map(ColorBand.of) == .blue)
        // Transparent pixels never count, however many there are.
        #expect(DominantColor.of(rgba: pixels([], transparent: 10)) == nil)
    }

    @Test func colorsComeFromBuiltInThenStoreThenYourFile() {
        let set = IconColorSet(
            builtIn: ["com.a": RGBColor(hex: "#FFFFFF")!, "com.b": RGBColor(hex: "#FFFFFF")!],
            store: ["com.b": RGBColor(hex: "#FF0000")!, "com.c": RGBColor(hex: "#00FF00")!],
            file: ["com.c": RGBColor(hex: "#0000FF")!]
        )
        #expect(set.merged["com.a"]?.hex == "#FFFFFF")
        #expect(set.merged["com.b"]?.hex == "#FF0000")
        #expect(set.merged["com.c"]?.hex == "#0000FF")
        #expect(set.source(of: "com.a") == .builtIn)
        #expect(set.source(of: "com.b") == .store)
        #expect(set.source(of: "com.c") == .file)
        #expect(set.source(of: "com.d") == nil)
    }

    @Test func theWheelPageListsAppsAndSlicesAndStaysOffline() {
        let apps = ColorWheelRenderer.apps(
            bundleIDs: ["com.b", "com.a", "com.b"],
            names: ["com.a": "Alpha", "com.b": "</script><b>Beta"],
            colors: IconColorSet(builtIn: [:], store: ["com.a": RGBColor(hex: "#FF0000")!])
        )
        #expect(apps.map { $0.bundleID } == ["com.b", "com.a"])
        #expect(apps.last?.source == "App Store icon")
        #expect(apps.first?.hex == nil)

        let html = ColorWheelRenderer.render(deviceName: "Test", apps: apps, fileColors: [:])
        for band in ColorBand.allCases {
            #expect(html.contains("data-band=\"\(band.rawValue)\""))
        }
        #expect(html.contains("1 of 2 apps have a color"))
        // An app name cannot end the data block early.
        #expect(!html.contains("</script><b>Beta"))
        #expect(!html.contains("http://"))
        #expect(!html.contains("https://"))
    }

    @Test func thePreviewLinksToTheWheelWhenThereIsOne() {
        let document = PreviewDocument(
            deviceName: "Test",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            names: [:],
            categories: [:],
            current: Fixtures.layout,
            plans: [],
            colorPage: "colors.html"
        )
        let html = HTMLPreviewRenderer.render(document)
        #expect(html.contains("href=\"colors.html\""))
        #expect(!html.contains("<script"))
    }
}
