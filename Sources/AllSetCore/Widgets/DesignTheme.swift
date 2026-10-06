import Foundation

/// Light, dark, or whatever the Mac is using.
public enum WidgetAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, light, dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// How eagerly a widget fetches or samples its data. Nothing refreshes while
/// a widget is covered; these are the gaps while it can be seen.
public enum RefreshPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case live, balanced, relaxed, manual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .live: "Live"
        case .balanced: "Balanced"
        case .relaxed: "Relaxed"
        case .manual: "Only When Clicked"
        }
    }

    /// Seconds between updates for a kind of data; nil for manual.
    public func interval(for data: RefreshData) -> TimeInterval? {
        let (live, balanced, relaxed): (TimeInterval, TimeInterval, TimeInterval) = switch data {
        case .systemStats: (1, 2, 5)
        case .wifi: (3, 10, 30)
        case .weather: (15 * 60, 30 * 60, 60 * 60)
        case .github: (5 * 60, 15 * 60, 60 * 60)
        case .status: (30, 120, 600)
        }
        switch self {
        case .live: return live
        case .balanced: return balanced
        case .relaxed: return relaxed
        case .manual: return nil
        }
    }
}

/// The kinds of data widgets refresh, each with its own sensible pace.
public enum RefreshData: Sendable {
    case systemStats, wifi, weather, github, status
}

/// How a design theme draws the card behind a widget.
public enum SurfaceStyle: String, Codable, Sendable {
    /// System material, like the Mac's own widgets.
    case native
    /// Translucent, blurred, with a specular edge and a wallpaper-aware tint.
    case liquidGlass
    case darkGlass
    /// Dark, with a faint, still wash of aurora light.
    case aurora
    /// Flat color, nothing else.
    case solid
    /// Near black, a faint grid, neon corner marks.
    case cyber
    /// Phosphor on black, with scan lines.
    case terminal
    /// A classic Mac window: white, black outline, striped title bar.
    case retro
    /// Washi paper and lots of room.
    case zen
    /// Newsprint, rules and serif headlines.
    case editorial
    /// Thick outline, hard offset shadow, no rounding.
    case brutalist
    /// Soft, extruded plastic.
    case neumorphic
    /// Warm paper with grain.
    case paper
    /// Near black, lit from within by the accent and a second glow.
    case glow
    /// A soft wash from the background into a second color.
    case gradient
    /// Brushed metal: silver, or gold foil, with a highlight.
    case chrome
}

/// How a theme moves: its widgets' transitions, how numbers change, how
/// widgets arrive on the desktop. Reduce Motion always wins.
public enum MotionLanguage: String, Codable, CaseIterable, Sendable {
    /// Slow fades and a soft glow.
    case calm
    /// Quick, precise, data-like.
    case energetic
    /// Almost none: things simply change.
    case still
    /// Springy and bright.
    case playful
    /// Long, slow, drifting.
    case orbital
    /// Measured, film-like dissolves.
    case cinematic

    public var title: String {
        switch self {
        case .calm: "Calm"
        case .energetic: "Energetic"
        case .still: "Still"
        case .playful: "Playful"
        case .orbital: "Orbital"
        case .cinematic: "Cinematic"
        }
    }

    public var summary: String {
        switch self {
        case .calm: "Slow fades and a soft glow."
        case .energetic: "Quick, crisp changes, like data arriving."
        case .still: "Almost no motion. Things simply change."
        case .playful: "Springy, bright and a little bouncy."
        case .orbital: "Long, slow, drifting movement."
        case .cinematic: "Measured dissolves, like a film cut."
        }
    }

    /// Seconds a widget takes to appear on the desktop.
    public var appearDuration: Double {
        switch self {
        case .calm: 0.6
        case .energetic: 0.2
        case .still: 0
        case .playful: 0.35
        case .orbital: 0.9
        case .cinematic: 0.8
        }
    }
}

/// How much a theme borrows from the desktop picture.
public enum WallpaperAdaptation: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A subtle accent taken from the wallpaper, for highlights and progress.
    case automatic
    /// The theme's own accent, always.
    case fixed
    /// No colored highlights at all: accents drawn in the ink's gray.
    case disabled

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .fixed: "Theme Color"
        case .disabled: "Off"
        }
    }
}

/// The weights a theme can ask for, without depending on SwiftUI here.
public enum ThemeWeight: String, Codable, Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

/// A theme's colors for one appearance.
public struct ThemePalette: Equatable, Sendable {
    public var background: WidgetColor
    public var ink: WidgetColor
    public var secondaryInk: WidgetColor
    public var accent: WidgetColor
    /// A hairline edge, when the theme has one.
    public var border: WidgetColor?
    /// Where gradient surfaces fade to, and the second light of glow ones.
    public var background2: WidgetColor?

    public init(background: Int, ink: Int, secondary: Int, accent: Int, border: Int? = nil, background2: Int? = nil) {
        self.background = WidgetColor(hex: background)
        self.ink = WidgetColor(hex: ink)
        self.secondaryInk = WidgetColor(hex: secondary)
        self.accent = WidgetColor(hex: accent)
        self.border = border.map(WidgetColor.init(hex:))
        self.background2 = background2.map(WidgetColor.init(hex:))
    }
}

/// A theme's type: system fonts only, in the design and weights it suits.
public struct ThemeTypography: Equatable, Sendable {
    public var font: WidgetFont
    /// Big numbers: times, temperatures, percentages.
    public var numberWeight: ThemeWeight
    public var titleWeight: ThemeWeight
    /// Small labels in spaced capitals ("CPU", "TODAY").
    public var uppercaseLabels: Bool
    public var labelTracking: Double

    public init(font: WidgetFont, numbers: ThemeWeight = .light, titles: ThemeWeight = .semibold,
                uppercaseLabels: Bool = false, tracking: Double = 0) {
        self.font = font
        numberWeight = numbers
        titleWeight = titles
        self.uppercaseLabels = uppercaseLabels
        labelTracking = tracking
    }
}

/// Where a theme's highlight color comes from.
public enum AccentSource: Sendable {
    case theme
    /// A subtle color taken from the desktop picture.
    case wallpaper
    /// The accent color chosen in System Settings.
    case system
}

/// How a widget's card casts its shadow.
public enum ThemeShadow: Sendable {
    case soft, none
    /// A solid offset block, no blur.
    case hard(Double)
    /// Light from the top left, shade to the bottom right.
    case neumorphic
}

/// One look for every widget: its card, colors in light and dark, type and
/// accent. Widgets render through the theme instead of styling themselves,
/// so a new theme restyles the whole catalog.
public struct DesignTheme: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let symbol: String
    public let surface: SurfaceStyle
    /// Nil when the theme is dark only.
    public let light: ThemePalette?
    /// Nil when the theme is light only.
    public let dark: ThemePalette?
    public let cornerRadius: Double
    public let typography: ThemeTypography
    public let accentSource: AccentSource
    public let shadow: ThemeShadow
    /// A live wallpaper that suits it, offered when applying the theme.
    public let wallpaper: WallpaperSource?
    /// Set for themes whose motion differs from their surface's usual one.
    public var motionOverride: MotionLanguage?

    /// How the theme moves: its own choice, or what suits its surface.
    public var motion: MotionLanguage {
        if let motionOverride { return motionOverride }
        switch surface {
        case .terminal, .cyber, .brutalist: return .energetic
        case .zen, .retro: return .still
        case .aurora: return .orbital
        case .editorial, .chrome: return .cinematic
        case .neumorphic, .gradient: return .playful
        default: return .calm
        }
    }

    /// Whether it draws dark, given the widget's setting and the Mac's.
    public func isDark(_ appearance: WidgetAppearance, systemIsDark: Bool) -> Bool {
        guard light != nil else { return true }
        guard dark != nil else { return false }
        switch appearance {
        case .auto: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }

    public func palette(dark isDark: Bool) -> ThemePalette {
        (isDark ? dark ?? light : light ?? dark)!
    }

    /// Themes with only one look ignore the appearance setting.
    public var followsAppearance: Bool { light != nil && dark != nil }
}

extension DesignTheme {
    public static func named(_ id: String?) -> DesignTheme? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static let all: [DesignTheme] = [
        native, liquidGlass, darkGlass, aurora, amoled, cyberpunk, terminal, retroMac, zen,
        editorial, brutalist, neumorphism, paper, monochrome, dynamicWallpaper,
    ]

    public static let native = DesignTheme(
        id: "native", title: "Apple Minimal", summary: "Quiet system material and SF Pro, like the Mac's own widgets.",
        symbol: "apple.logo", surface: .native,
        light: ThemePalette(background: 0xF5F5F7, ink: 0x1D1D1F, secondary: 0x6E6E73, accent: 0x0071E3),
        dark: ThemePalette(background: 0x1C1C1E, ink: 0xF5F5F7, secondary: 0x98989D, accent: 0x0A84FF),
        cornerRadius: 22, typography: ThemeTypography(font: .standard), accentSource: .system, shadow: .soft, wallpaper: nil)

    public static let liquidGlass = DesignTheme(
        id: "liquidGlass", title: "Liquid Glass", summary: "Clear glass with a bright edge, tinted by your wallpaper.",
        symbol: "drop.fill", surface: .liquidGlass,
        light: ThemePalette(background: 0xFFFFFF, ink: 0x111114, secondary: 0x5E5E66, accent: 0x0A84FF),
        dark: ThemePalette(background: 0x0B0B10, ink: 0xFFFFFF, secondary: 0xB4B4BE, accent: 0x64D2FF),
        cornerRadius: 26, typography: ThemeTypography(font: .standard), accentSource: .wallpaper, shadow: .soft, wallpaper: nil)

    public static let darkGlass = DesignTheme(
        id: "darkGlass", title: "Dark Glass", summary: "Smoked glass that lets the wallpaper glow through.",
        symbol: "square.stack.3d.down.forward.fill", surface: .darkGlass,
        light: nil, dark: ThemePalette(background: 0x0B0B0F, ink: 0xF2F2F7, secondary: 0x8E8E93, accent: 0x7D7AFF),
        cornerRadius: 22, typography: ThemeTypography(font: .standard), accentSource: .theme, shadow: .soft, wallpaper: nil)

    public static let aurora = DesignTheme(
        id: "aurora", title: "Aurora", summary: "Deep night blue with the faintest northern light.",
        symbol: "sparkles", surface: .aurora,
        light: nil, dark: ThemePalette(background: 0x070B1A, ink: 0xEAF2FF, secondary: 0x8C9BB5, accent: 0x5EF2C4),
        cornerRadius: 24, typography: ThemeTypography(font: .rounded), accentSource: .theme, shadow: .soft,
        wallpaper: .art(ArtPiece(style: .aurora, palette: .aurora)))

    public static let amoled = DesignTheme(
        id: "amoled", title: "AMOLED", summary: "True black. Nothing lit that doesn't need to be.",
        symbol: "circle.fill", surface: .solid,
        light: nil, dark: ThemePalette(background: 0x000000, ink: 0xFFFFFF, secondary: 0x8E8E93, accent: 0xFF375F),
        cornerRadius: 20, typography: ThemeTypography(font: .standard, numbers: .thin), accentSource: .theme, shadow: .none, wallpaper: nil)

    public static let cyberpunk = DesignTheme(
        id: "cyberpunk", title: "Cyberpunk", summary: "Night city black, signal yellow, a magenta edge.",
        symbol: "bolt.horizontal.fill", surface: .cyber,
        light: nil, dark: ThemePalette(background: 0x0A0A12, ink: 0xF4F4F8, secondary: 0x8A8AA3, accent: 0xFCEE0A, border: 0xFF2A6D),
        cornerRadius: 6, typography: ThemeTypography(font: .condensed, numbers: .semibold, titles: .bold, uppercaseLabels: true, tracking: 1.5),
        accentSource: .theme, shadow: .none, wallpaper: .art(ArtPiece(style: .skyline, palette: .neon)))

    public static let terminal = DesignTheme(
        id: "terminal", title: "Terminal", summary: "Phosphor green on black, set in SF Mono.",
        symbol: "terminal.fill", surface: .terminal,
        light: nil, dark: ThemePalette(background: 0x0A0F0A, ink: 0x33FF77, secondary: 0x1FA04A, accent: 0x33FF77),
        cornerRadius: 8, typography: ThemeTypography(font: .monospaced, numbers: .regular, titles: .medium),
        accentSource: .theme, shadow: .none, wallpaper: nil)

    public static let retroMac = DesignTheme(
        id: "retroMac", title: "Retro Macintosh", summary: "A 1984 window: black outline, striped title bar.",
        symbol: "desktopcomputer", surface: .retro,
        light: ThemePalette(background: 0xFFFFFF, ink: 0x000000, secondary: 0x4A4A4A, accent: 0x000000, border: 0x000000),
        dark: nil, cornerRadius: 3, typography: ThemeTypography(font: .monospaced, numbers: .bold, titles: .bold),
        accentSource: .theme, shadow: .hard(3), wallpaper: nil)

    public static let zen = DesignTheme(
        id: "zen", title: "Japanese Zen", summary: "Washi paper, sumi ink, a single vermilion mark.",
        symbol: "leaf.fill", surface: .zen,
        light: ThemePalette(background: 0xF3EFE6, ink: 0x2B2A27, secondary: 0x8A857B, accent: 0xB5452E),
        dark: ThemePalette(background: 0x1B1A18, ink: 0xE9E4D8, secondary: 0x8F897D, accent: 0xD0654A),
        cornerRadius: 16, typography: ThemeTypography(font: .serif, numbers: .ultraLight, titles: .regular),
        accentSource: .theme, shadow: .soft, wallpaper: nil)

    public static let editorial = DesignTheme(
        id: "editorial", title: "Editorial", summary: "Newsprint, fine rules and serif headlines.",
        symbol: "newspaper.fill", surface: .editorial,
        light: ThemePalette(background: 0xFAF9F6, ink: 0x111111, secondary: 0x6B6B6B, accent: 0xD72C1E),
        dark: ThemePalette(background: 0x121212, ink: 0xF2F0EB, secondary: 0x8C8C8C, accent: 0xFF5A45),
        cornerRadius: 10, typography: ThemeTypography(font: .serif, numbers: .regular, titles: .bold, uppercaseLabels: true, tracking: 2),
        accentSource: .theme, shadow: .soft, wallpaper: nil)

    public static let brutalist = DesignTheme(
        id: "brutalist", title: "Brutalist", summary: "Heavy outlines, hard shadows, no apologies.",
        symbol: "square.fill", surface: .brutalist,
        light: ThemePalette(background: 0xF2F0E9, ink: 0x000000, secondary: 0x3A3A3A, accent: 0xFF4D00, border: 0x000000),
        dark: ThemePalette(background: 0x111111, ink: 0xF2F0E9, secondary: 0xBBBBBB, accent: 0xFF4D00, border: 0xF2F0E9),
        cornerRadius: 0, typography: ThemeTypography(font: .standard, numbers: .black, titles: .heavy, uppercaseLabels: true, tracking: 0.5),
        accentSource: .theme, shadow: .hard(5), wallpaper: nil)

    public static let neumorphism = DesignTheme(
        id: "neumorphism", title: "Neumorphism", summary: "Soft plastic, lit from the top left.",
        symbol: "circle.circle.fill", surface: .neumorphic,
        light: ThemePalette(background: 0xE6E9EF, ink: 0x2E3440, secondary: 0x7B8494, accent: 0x5B7FFF),
        dark: ThemePalette(background: 0x2A2D34, ink: 0xE5E9F0, secondary: 0x8A93A6, accent: 0x7C9CFF),
        cornerRadius: 28, typography: ThemeTypography(font: .rounded, numbers: .medium),
        accentSource: .theme, shadow: .neumorphic, wallpaper: nil)

    public static let paper = DesignTheme(
        id: "paper", title: "Paper", summary: "Warm, grainy paper and pencil-soft ink.",
        symbol: "doc.plaintext.fill", surface: .paper,
        light: ThemePalette(background: 0xF5F1E8, ink: 0x2B2A28, secondary: 0x857F74, accent: 0xC4572B),
        dark: ThemePalette(background: 0x1E1D1B, ink: 0xECE6DA, secondary: 0x8E887D, accent: 0xE07A4F),
        cornerRadius: 14, typography: ThemeTypography(font: .serif, numbers: .light),
        accentSource: .theme, shadow: .soft, wallpaper: nil)

    public static let monochrome = DesignTheme(
        id: "monochrome", title: "Monochrome", summary: "Black and white, and every gray between.",
        symbol: "circle.lefthalf.filled", surface: .solid,
        light: ThemePalette(background: 0xFFFFFF, ink: 0x000000, secondary: 0x8A8A8A, accent: 0x000000),
        dark: ThemePalette(background: 0x0E0E0E, ink: 0xFFFFFF, secondary: 0x7A7A7A, accent: 0xFFFFFF),
        cornerRadius: 18, typography: ThemeTypography(font: .standard, numbers: .light, titles: .semibold),
        accentSource: .theme, shadow: .soft, wallpaper: nil)

    public static let dynamicWallpaper = DesignTheme(
        id: "dynamicWallpaper", title: "Dynamic Wallpaper", summary: "Native cards that borrow a quiet color from your desktop.",
        symbol: "photo.artframe", surface: .native,
        light: ThemePalette(background: 0xF5F5F7, ink: 0x1D1D1F, secondary: 0x6E6E73, accent: 0x0071E3),
        dark: ThemePalette(background: 0x1C1C1E, ink: 0xF5F5F7, secondary: 0x98989D, accent: 0x0A84FF),
        cornerRadius: 22, typography: ThemeTypography(font: .standard), accentSource: .wallpaper, shadow: .soft, wallpaper: nil)
}

extension WidgetColor {
    /// The same hue, made to read on a light or dark card: deeper on light,
    /// brighter on dark, never neon.
    public func adjusted(forDark isDark: Bool) -> WidgetColor {
        var (h, s, v) = hsv
        s = min(s, 0.72)
        v = isDark ? min(max(v, 0.78), 0.95) : min(max(v, 0.42), 0.62)
        return WidgetColor(hue: h, saturation: s, value: v)
    }

    var hsv: (Double, Double, Double) {
        let maxC = max(red, green, blue), minC = min(red, green, blue), delta = maxC - minC
        var hue = 0.0
        if delta > 0 {
            if maxC == red { hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == green { hue = (blue - red) / delta + 2 }
            else { hue = (red - green) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxC == 0 ? 0 : delta / maxC, maxC)
    }

    public init(hue: Double, saturation: Double, value: Double) {
        let h = (hue - hue.rounded(.down)) * 6, c = value * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)), m = value - c
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m)
    }
}
