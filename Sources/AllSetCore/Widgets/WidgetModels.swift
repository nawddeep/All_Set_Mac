import CoreGraphics
import Foundation

public enum WidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case clock
    case calendar
    case weather
    case system
    case battery
    case nowPlaying
    case note
    case photo
    case ambient
    case quote
    case countdown
    case lockScreen
    case vinyl
    case moon
    case daylight
    case polaroids
    case todo
    case focus
    case stopwatch
    case shortcuts
    case sticker
    case neon
    case terminal
    case dots
    /// One system reading, chosen in its options: CPU, memory, Wi-Fi…
    case metric
    case date
    case nextEvent
    case goals
    case habits
    case reading
    case github
    case status
    case airQuality
    case retroWindow
    case enso
    case magazine
    // Football
    case jersey
    case playerCard
    case pitch
    case scoreboard
    case milestone
    // Music
    case cassette
    case vhs
    case visualizer
    case ticket
    /// Words in chrome, gold, neon or glitter, straight on the desktop.
    case wordArt
    /// An op-art spiral that turns slowly.
    case spiral
    /// A chrome charm, hanging on the desktop.
    case charm
    /// A perfume-bottle label with your words.
    case label
    // Mystic
    case aura
    case tarot
    case zodiac
    case eightBall
    case candle

    public var id: String { rawValue }

    private var definition: WidgetKindDefinition { WidgetKindDefinition.of(self) }

    public var category: WidgetCategory { definition.category }
    public var title: String { definition.title }
    public var symbol: String { definition.symbol }
    public var summary: String { definition.summary }
    public var keywords: String { definition.keywords }
    /// The sizes it has layouts for.
    public var supportedSizes: [WidgetSize] { definition.sizes }
    /// Drawn straight onto the desktop, with no card behind it.
    public var isFreeform: Bool { definition.isFreeform }
    /// Kinds that paint their own backgrounds, so card styles don't apply.
    public var paintsOwnBackground: Bool { definition.paintsOwnBackground }
    public var defaultSize: WidgetSize { definition.defaultSize }
}

public enum WidgetSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large
    /// Two larges side by side, for the widgets that have that much to say.
    case extraLarge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    /// "S", "M", "L", "XL".
    public var shortTitle: String { self == .extraLarge ? "XL" : String(title.prefix(1)) }

    /// Close to macOS's own widget sizes, adjusted so sizes, gaps and margins
    /// all fall on the 8-point layout grid: two smalls and a gap make a medium,
    /// two mediums and a gap make a large.
    public var dimensions: CGSize {
        switch self {
        case .small: CGSize(width: 168, height: 168)
        case .medium: CGSize(width: 352, height: 168)
        case .large: CGSize(width: 352, height: 352)
        case .extraLarge: CGSize(width: 720, height: 352)
        }
    }
}

public enum WidgetMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass
    case dark
    case light
    case tinted
    /// A flat, opaque card in the tint, like paper or a matte print.
    case paper
    /// Frosted glass washed with the tint.
    case frosted
    /// No card at all: the content sits right on the wallpaper.
    case clear
    /// A hairline edge on a faint dark wash.
    case outline
    /// Generative art from the library, still or animated.
    case art
    /// A photo, shaded so text reads on top of it.
    case photo
    /// Soft colors drifting into one another.
    case mesh

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .glass: "Glass"
        case .dark: "Dark"
        case .light: "Light"
        case .tinted: "Color"
        case .paper: "Solid"
        case .frosted: "Frosted"
        case .clear: "No Card"
        case .outline: "Outline"
        case .art: "Art"
        case .photo: "Photo"
        case .mesh: "Mesh"
        }
    }
}

public enum WidgetCategory: String, CaseIterable, Identifiable, Sendable {
    case time
    case productivity
    case system
    case developer
    case lifestyle
    /// Decorative widgets: stickers, signs, prints and scenes.
    case aesthetic
    case football
    case music
    /// Tarot, star signs, auras: a little magic.
    case mystic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .time: "Time"
        case .productivity: "Productivity"
        case .system: "System"
        case .developer: "Developer"
        case .lifestyle: "Lifestyle"
        case .aesthetic: "Aesthetic"
        case .football: "Football"
        case .music: "Music"
        case .mystic: "Mystic"
        }
    }

    public var symbol: String {
        switch self {
        case .time: "clock.fill"
        case .productivity: "checklist"
        case .system: "cpu"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .lifestyle: "sun.max.fill"
        case .aesthetic: "sparkles"
        case .football: "soccerball"
        case .music: "music.mic"
        case .mystic: "moon.stars.fill"
        }
    }

    public var kinds: [WidgetKind] { WidgetKind.allCases.filter { $0.category == self } }
}

public enum PhotoFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, mono, noir, warm, cool, vintage, fade, dreamy, duotone

    public var id: String { rawValue }
    public var title: String { self == .none ? "Original" : rawValue.capitalized }
}

public enum PhotoFrame: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullBleed, polaroid, inset
    /// Up to six pictures in a mosaic.
    case collage
    /// Frames on a strip of 35 mm film.
    case filmStrip

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fullBleed: "Full"
        case .polaroid: "Polaroid"
        case .inset: "Inset"
        case .collage: "Collage"
        case .filmStrip: "Film Strip"
        }
    }
}

/// What a Live Scene shows over its art.
public enum SceneOverlay: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, time, date, text

    public var id: String { rawValue }
    public var title: String { self == .none ? "Nothing" : rawValue.capitalized }
}

public enum QuoteSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case affirmations, custom

    public var id: String { rawValue }
    public var title: String { self == .affirmations ? "Rotating lines" : "My own words" }
}

/// Typography for text-forward widgets.
public enum TextStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, modern, bold, elegant, script, handwritten, typewriter
    /// Huge condensed capitals: "GOOD THINGS".
    case poster
    /// Soft, heavy serif: "it comes in waves".
    case chunky
    /// Small spaced-out capitals in a serif, like a magazine.
    case editorial
    /// Medieval, candlelit lettering.
    case gothic
    /// High-contrast fashion serif in capitals.
    case luxe

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// Styles set in capitals.
    public var isUppercased: Bool { self == .poster || self == .editorial || self == .luxe }
}

public enum WidgetFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case rounded
    case serif
    case monospaced
    /// Tall and narrow.
    case condensed
    /// Wide, Y2K-style.
    case expanded

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: "Default"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Mono"
        case .condensed: "Tall"
        case .expanded: "Wide"
        }
    }
}

public enum ClockFace: String, Codable, CaseIterable, Identifiable, Sendable {
    case digital
    case analog
    /// Hours above minutes, big, as on the iPhone lock screen.
    case stacked
    /// "Half past ten", spelled out.
    case words
    /// Split-flap tiles, like an old airport board.
    case flip
    /// Just the time, thin and large.
    case minimal
    /// Several cities at once.
    case world

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum NoteColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case yellow
    case pink
    case blue
    case green
    case purple

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// An sRGB color that survives a round trip through JSON.
public struct WidgetColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let presets: [WidgetColor] = [
        WidgetColor(red: 0.36, green: 0.42, blue: 0.98), // indigo
        WidgetColor(red: 0.96, green: 0.36, blue: 0.52), // rose
        WidgetColor(red: 0.18, green: 0.72, blue: 0.62), // teal
        WidgetColor(red: 0.98, green: 0.58, blue: 0.22), // amber
        WidgetColor(red: 0.62, green: 0.38, blue: 0.96), // violet
        WidgetColor(hex: 0xF4EEE4), // cream
        WidgetColor(hex: 0xF7C6D9), // blush
        WidgetColor(hex: 0xA9C4F5), // baby blue
        WidgetColor(hex: 0x8E5E72), // mauve
        WidgetColor(hex: 0x111111), // black
        WidgetColor(hex: 0xFAFAFA), // white
    ]

    /// Perceived brightness, 0 (black) to 1 (white).
    public var luminance: Double { 0.299 * red + 0.587 * green + 0.114 * blue }
    public var isLight: Bool { luminance > 0.6 }
}

/// The big shape a Sticker shows.
public enum StickerShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case star, heart, sparkles, moon, cloud, bolt, flower, crown, smiley, eye, cat, teddy, music, flame, snowflake, spiral

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The SF Symbol it's drawn from.
    public var symbol: String {
        switch self {
        case .star: "star.fill"
        case .heart: "heart.fill"
        case .sparkles: "sparkles"
        case .moon: "moon.stars.fill"
        case .cloud: "cloud.fill"
        case .bolt: "bolt.fill"
        case .flower: "camera.macro"
        case .crown: "crown.fill"
        case .smiley: "face.smiling.inverse"
        case .eye: "eye.fill"
        case .cat: "cat.fill"
        case .teddy: "teddybear.fill"
        case .music: "music.note"
        case .flame: "flame.fill"
        case .snowflake: "snowflake"
        case .spiral: "hurricane"
        }
    }
}

/// How a Sticker is finished.
public enum StickerFinish: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Blurred at the edges, glowing, like a dream.
    case soft
    /// Puffy, with a shine: Y2K.
    case glossy
    /// Silver, like chrome.
    case chrome
    /// Flat color.
    case solid
    /// Just the edge.
    case outline

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// One icon in a Shortcuts widget.
public struct ShortcutItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// An SF Symbol name.
    public var symbol: String
    public var title: String
    /// What it opens: a web or app URL ("https://…", "spotify:"), an app's
    /// bundle identifier ("com.apple.Music"), or the path of an app.
    public var target: String

    public init(id: UUID = UUID(), symbol: String = "star.fill", title: String, target: String) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.target = target
    }

    /// Whether `target` is a URL rather than an app.
    public var isLink: Bool { target.contains(":") && !target.hasPrefix("/") }

    /// Fixed ids, so default options always compare equal.
    public static let starters: [ShortcutItem] = [
        ("photos", "com.apple.Photos"), ("music", "com.apple.Music"), ("pinterest", "https://www.pinterest.com"),
        ("notes", "com.apple.Notes"), ("safari", "com.apple.Safari"), ("mail", "com.apple.mail"),
        ("calendar", "com.apple.iCal"), ("youtube", "https://www.youtube.com"), ("finder", "com.apple.finder"),
    ].enumerated().map { index, item in
        ShortcutItem(id: UUID(uuidString: String(format: "5A0C0000-0000-4000-8000-%012d", index))!, title: item.0, target: item.1)
    }
}

public struct WeatherLocation: Codable, Hashable, Sendable {
    public var name: String
    public var region: String?
    public var country: String?
    public var latitude: Double
    public var longitude: Double

    public init(name: String, region: String? = nil, country: String? = nil, latitude: Double, longitude: Double) {
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    /// "Pune, Maharashtra, India"
    public var fullName: String {
        [name, region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
