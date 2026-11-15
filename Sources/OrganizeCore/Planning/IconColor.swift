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
