import Foundation

/// The light a theme casts in the Themes hero: along its card's edge, in
/// the glow around it and across the atmosphere behind. Chosen by hand for
/// the themes that lead the library (`ThemeLibrary.accents`): measuring a
/// picture's average gives mud for most themes and gray for the
/// black-and-white ones. Every other theme's is worked out by
/// `ThemeSet.lighting`.
public struct ThemeAccent: Equatable, Sendable {
    /// Neon, edges and glow.
    public let primary: WidgetColor
    /// Haze: a second, quieter color beside the first.
    public let secondary: WidgetColor
    /// How strongly it glows, 0.6...1: lower for bright themes, whose own
    /// picture already carries light.
    public let glowIntensity: Double

    public init(primary: WidgetColor, secondary: WidgetColor, glowIntensity: Double = 1) {
        self.primary = primary
        self.secondary = secondary
        self.glowIntensity = min(max(glowIntensity, 0.6), 1)
    }

    init(_ primary: Int, _ secondary: Int, glow: Double = 1) {
        self.init(primary: WidgetColor(hex: primary), secondary: WidgetColor(hex: secondary), glowIntensity: glow)
    }

    /// For a theme nobody has chosen a light for and that has no color to
    /// offer: warm gold.
    public static let neutral = ThemeAccent(0xD9B38C, 0x8A6A3A, glow: 0.8)
}

extension WidgetColor {
    /// Enough color to light something with: not near black, not near gray.
    /// White on a black-and-white theme fails this and is passed over.
    var hasColor: Bool {
        let (_, saturation, value) = hsv
        return value > 0.3 && saturation >= 0.18
    }

    /// The same hue, bright enough to glow.
    var lit: WidgetColor {
        let lift = 0.94 / max(red, green, blue, 0.01)
        return WidgetColor(red: min(red * lift, 1), green: min(green * lift, 1), blue: min(blue * lift, 1))
    }

    /// Half way to white: the same color as haze.
    var paled: WidgetColor {
        WidgetColor(red: (red + 1) / 2, green: (green + 1) / 2, blue: (blue + 1) / 2)
    }

    /// How far apart two hues are, 0 (the same) to 0.5 (opposite).
    func hueDistance(to other: WidgetColor) -> Double {
        let apart = abs(hsv.0 - other.hsv.0)
        return min(apart, 1 - apart)
    }
}
