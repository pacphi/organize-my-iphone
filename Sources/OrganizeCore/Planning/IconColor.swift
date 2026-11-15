import Foundation

/// A color with red, green and blue in 0...1.
public struct RGBColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// Reads `#RRGGBB` or `RRGGBB`. Returns `nil` for anything else.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        guard text.count == 6, let value = UInt32(text, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    public var hex: String {
        func byte(_ value: Double) -> String {
            let text = String(Int((value * 255).rounded()), radix: 16, uppercase: true)
            return text.count == 1 ? "0" + text : text
        }
        return "#" + byte(red) + byte(green) + byte(blue)
    }

    /// Hue in degrees (0..<360), saturation and brightness in 0...1.
    public var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let high = max(red, green, blue)
        let low = min(red, green, blue)
        let delta = high - low
        var hue = 0.0
        if delta > 0 {
            if high == red {
                hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if high == green {
                hue = 60 * ((blue - red) / delta + 2)
            } else {
                hue = 60 * ((red - green) / delta + 4)
            }
        }
        if hue < 0 {
            hue += 360
        }
        return (hue, high == 0 ? 0 : delta / high, high)
    }
}

/// The color bands of the rainbow layout, in the order they appear.
public enum ColorBand: String, CaseIterable, Sendable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case teal = "Teal"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case white = "White"
    case gray = "Gray"
    case black = "Black"

    /// The band a color falls in. Pale or dark colors count as white, gray or black.
    public static func of(_ color: RGBColor) -> ColorBand {
        let (hue, saturation, brightness) = color.hsb
        if brightness < 0.22 {
            return .black
        }
        if saturation < 0.18 {
            if brightness > 0.85 {
                return .white
            }
            return brightness < 0.3 ? .black : .gray
        }
        switch hue {
        case 15..<45: return .orange
        case 45..<70: return .yellow
        case 70..<165: return .green
        case 165..<195: return .teal
        case 195..<255: return .blue
        case 255..<290: return .purple
        case 290..<345: return .pink
        default: return .red
        }
    }
}

extension ColorBand {
    /// A representative color for the band, used for swatches on the color-wheel page.
    public var swatch: RGBColor {
        switch self {
        case .red: return RGBColor(hex: "#FF3B30")!
        case .orange: return RGBColor(hex: "#FF9500")!
        case .yellow: return RGBColor(hex: "#FFD60A")!
        case .green: return RGBColor(hex: "#34C759")!
        case .teal: return RGBColor(hex: "#30B0C7")!
        case .blue: return RGBColor(hex: "#007AFF")!
        case .purple: return RGBColor(hex: "#8E44D9")!
        case .pink: return RGBColor(hex: "#FF2D92")!
        case .white: return RGBColor(hex: "#F5F5F7")!
        case .gray: return RGBColor(hex: "#8E8E93")!
        case .black: return RGBColor(hex: "#1C1C1E")!
        }
    }
}

/// Finds the main color of an icon from its pixels.
///
/// Each visible pixel is matched to its slice of the color wheel (`ColorBand`). The slice with
/// the most pixels wins, and the result is the average of the pixels in that slice, so a blue
/// icon with a white logo comes out blue, and a white icon with a small red mark comes out white.
public enum DominantColor {
    /// - Parameter rgba: Pixels as 8-bit red, green, blue, alpha, four bytes per pixel. Colors
    ///   need not be premultiplied; pixels less than half opaque are ignored.
    public static func of(rgba: [UInt8]) -> RGBColor? {
        var counts: [ColorBand: Int] = [:]
        var sums: [ColorBand: (red: Double, green: Double, blue: Double)] = [:]
        var index = 0
        while index + 3 < rgba.count {
            defer { index += 4 }
            guard rgba[index + 3] >= 128 else {
                continue
            }
            let color = RGBColor(
                red: Double(rgba[index]) / 255,
                green: Double(rgba[index + 1]) / 255,
                blue: Double(rgba[index + 2]) / 255
            )
            let band = ColorBand.of(color)
            counts[band, default: 0] += 1
            let sum = sums[band] ?? (0, 0, 0)
            sums[band] = (sum.red + color.red, sum.green + color.green, sum.blue + color.blue)
        }
        // Ties go to the band that comes first on the wheel, so the answer never depends on
        // dictionary order.
        guard
            let winner = ColorBand.allCases.max(by: { left, right in
                let leftCount = counts[left] ?? 0
                let rightCount = counts[right] ?? 0
                if leftCount != rightCount {
                    return leftCount < rightCount
                }
                return ColorBand.allCases.firstIndex(of: left)! > ColorBand.allCases.firstIndex(of: right)!
            }),
            let count = counts[winner], count > 0, let sum = sums[winner]
        else {
            return nil
        }
        let total = Double(count)
        return RGBColor(red: sum.red / total, green: sum.green / total, blue: sum.blue / total)
    }
}

/// Icon colors from every source, with the order they override each other in:
/// built-in (Apple's apps) < App Store artwork < your `--icon-colors` file.
public struct IconColorSet: Hashable, Sendable {
    public enum Source: String, Sendable {
        case builtIn = "built-in"
        case store = "App Store icon"
        case file = "your file"
    }

    public var builtIn: [String: RGBColor]
    public var store: [String: RGBColor]
    public var file: [String: RGBColor]

    public init(
        builtIn: [String: RGBColor] = IconColorSet.appleApps,
        store: [String: RGBColor] = [:],
        file: [String: RGBColor] = [:]
    ) {
        self.builtIn = builtIn
        self.store = store
        self.file = file
    }

    public var merged: [String: RGBColor] {
        builtIn.merging(store) { _, new in new }.merging(file) { _, new in new }
    }

    public func source(of bundleID: String) -> Source? {
        if file[bundleID] != nil { return .file }
        if store[bundleID] != nil { return .store }
        if builtIn[bundleID] != nil { return .builtIn }
        return nil
    }

    /// The built-in colors of Apple's own apps.
    public static var appleApps: [String: RGBColor] {
        KnownApps.iconColors.compactMapValues { RGBColor(hex: $0) }
    }
}
