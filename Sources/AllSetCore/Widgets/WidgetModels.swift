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

    public var category: WidgetCategory {
        switch self {
        case .clock, .countdown, .stopwatch, .dots, .date: .time
        case .calendar, .note, .todo, .focus, .shortcuts, .nextEvent, .goals, .habits: .productivity
        case .system, .battery, .metric, .terminal: .system
        case .github, .status: .developer
        case .weather, .nowPlaying, .quote, .photo, .moon, .daylight, .reading, .airQuality: .lifestyle
        case .lockScreen, .polaroids, .sticker, .neon, .ambient, .vinyl, .retroWindow, .enso, .magazine, .wordArt,
             .spiral, .charm, .label: .aesthetic
        case .jersey, .playerCard, .pitch, .scoreboard, .milestone: .football
        case .cassette, .vhs, .visualizer, .ticket: .music
        case .aura, .tarot, .zodiac, .eightBall, .candle: .mystic
        }
    }

    public var title: String {
        switch self {
        case .clock: "Clock"
        case .calendar: "Calendar"
        case .weather: "Weather"
        case .system: "System"
        case .battery: "Battery"
        case .nowPlaying: "Now Playing"
        case .note: "Note"
        case .photo: "Photo"
        case .ambient: "Live Scene"
        case .quote: "Quote"
        case .countdown: "Countdown"
        case .lockScreen: "Lock Screen"
        case .vinyl: "Vinyl"
        case .moon: "Moon"
        case .daylight: "Daylight"
        case .polaroids: "Polaroids"
        case .todo: "To-Do"
        case .focus: "Focus Timer"
        case .stopwatch: "Stopwatch"
        case .shortcuts: "Shortcuts"
        case .sticker: "Sticker"
        case .neon: "Neon Sign"
        case .terminal: "Terminal"
        case .dots: "Year in Dots"
        case .metric: "System Metric"
        case .date: "Date"
        case .nextEvent: "Next Event"
        case .goals: "Daily Goals"
        case .habits: "Habit Tracker"
        case .reading: "Reading Progress"
        case .github: "GitHub"
        case .status: "Status"
        case .airQuality: "Air Quality"
        case .retroWindow: "Classic Mac"
        case .enso: "Ensō"
        case .magazine: "Magazine Cover"
        case .jersey: "Shirt"
        case .playerCard: "Player Card"
        case .pitch: "Tactics Board"
        case .scoreboard: "Scoreboard"
        case .milestone: "Milestone"
        case .cassette: "Cassette"
        case .vhs: "VHS"
        case .visualizer: "Visualizer"
        case .ticket: "Ticket"
        case .wordArt: "Word Art"
        case .spiral: "Spiral"
        case .charm: "Charm"
        case .label: "Label"
        case .aura: "Aura"
        case .tarot: "Tarot"
        case .zodiac: "Star Sign"
        case .eightBall: "Magic Ball"
        case .candle: "Candle"
        }
    }

    public var symbol: String {
        switch self {
        case .clock: "clock.fill"
        case .calendar: "calendar"
        case .weather: "cloud.sun.fill"
        case .system: "cpu"
        case .battery: "battery.100percent"
        case .nowPlaying: "music.note"
        case .note: "note.text"
        case .photo: "photo.fill"
        case .ambient: "sparkles"
        case .quote: "quote.opening"
        case .countdown: "hourglass"
        case .lockScreen: "lock.fill"
        case .vinyl: "opticaldisc.fill"
        case .moon: "moon.stars.fill"
        case .daylight: "sun.horizon.fill"
        case .polaroids: "photo.stack.fill"
        case .todo: "checklist"
        case .focus: "timer"
        case .stopwatch: "stopwatch.fill"
        case .shortcuts: "square.grid.3x2.fill"
        case .sticker: "heart.fill"
        case .neon: "lightbulb.fill"
        case .terminal: "terminal.fill"
        case .dots: "circle.grid.3x3.fill"
        case .metric: "gauge.with.dots.needle.33percent"
        case .date: "calendar.day.timeline.left"
        case .nextEvent: "calendar.badge.clock"
        case .goals: "target"
        case .habits: "checkmark.seal.fill"
        case .reading: "book.fill"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .status: "waveform.path.ecg"
        case .airQuality: "aqi.medium"
        case .retroWindow: "macwindow"
        case .enso: "circle.dashed"
        case .magazine: "newspaper.fill"
        case .jersey: "tshirt.fill"
        case .playerCard: "person.crop.rectangle.fill"
        case .pitch: "sportscourt.fill"
        case .scoreboard: "rectangle.split.2x1.fill"
        case .milestone: "trophy.fill"
        case .cassette: "recordingtape"
        case .vhs: "video.fill"
        case .visualizer: "waveform"
        case .ticket: "ticket.fill"
        case .wordArt: "textformat"
        case .spiral: "tornado"
        case .charm: "heart.fill"
        case .label: "drop.fill"
        case .aura: "circle.hexagongrid.fill"
        case .tarot: "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .zodiac: "sparkles"
        case .eightBall: "8.circle.fill"
        case .candle: "flame.fill"
        }
    }

    public var summary: String {
        switch self {
        case .clock: "Digital or analog, any time zone"
        case .calendar: "The month and what's coming up"
        case .weather: "Conditions and forecast for a city"
        case .system: "CPU, GPU, memory and top apps"
        case .battery: "Charge, health and power draw"
        case .nowPlaying: "Artwork and playback controls"
        case .note: "A sticky note for the desktop"
        case .photo: "Your photos, art or a slideshow"
        case .ambient: "Animated art with the time on top"
        case .quote: "Words to live by, beautifully set"
        case .countdown: "Days until something good"
        case .lockScreen: "A big clock over a photo, like your iPhone"
        case .vinyl: "A record that spins while music plays"
        case .moon: "Tonight's moon and the phases ahead"
        case .daylight: "The sky right now, from sunrise to starlight"
        case .polaroids: "A little pile of prints. Click to shuffle"
        case .todo: "Tick things off. Syncs with the notch's Notes"
        case .focus: "Pomodoro sessions, with breaks in between"
        case .stopwatch: "Time anything, to the hundredth"
        case .shortcuts: "Cute icons that open your apps and sites"
        case .sticker: "A big star, heart or sparkle on the desktop"
        case .neon: "Your words in glowing tubes, flickering now and then"
        case .terminal: "Live stats in green on black, like a hacker"
        case .dots: "The year, or this month, as a grid of dots"
        case .metric: "One reading from your Mac, beautifully"
        case .date: "Today's date, big and clear"
        case .nextEvent: "What's next on your calendar, and when"
        case .goals: "A few counts to hit today"
        case .habits: "Streaks for the things you do every day"
        case .reading: "How far through your book you are"
        case .github: "Contributions, pull requests, issues and CI"
        case .status: "Whether your sites and APIs are up"
        case .airQuality: "The air outside, by US AQI"
        case .retroWindow: "The time in a 1984 Mac window"
        case .enso: "A brush circle that closes as the day ends"
        case .magazine: "Today as the cover of a magazine"
        case .jersey: "Your name and number on a glowing shirt"
        case .playerCard: "A foil rating card with your photo and stats"
        case .pitch: "A live tactics board with the ball in play"
        case .scoreboard: "A stadium board counting down to kickoff"
        case .milestone: "One big number worth celebrating"
        case .cassette: "A mixtape whose reels turn while music plays"
        case .vhs: "A photo on an old tape, tracking lines and all"
        case .visualizer: "Glowing bars that dance to your music"
        case .ticket: "A ticket stub counting down to the show"
        case .wordArt: "Words in chrome, gold, neon or glitter"
        case .spiral: "A hypnotic spiral that never stops turning"
        case .charm: "A chrome charm that catches the light"
        case .label: "Your name on a perfume label"
        case .aura: "Today's aura, glowing in its colors"
        case .tarot: "A card drawn for you each day"
        case .zodiac: "Your sign's stars, twinkling"
        case .eightBall: "Ask a question, shake for an answer"
        case .candle: "A candle flickering on your desktop"
        }
    }

    /// Extra words the gallery search matches, beyond the title and summary.
    public var keywords: String {
        switch self {
        case .clock: "time watch flip digital analog world"
        case .calendar: "date month events schedule"
        case .weather: "forecast temperature rain sun"
        case .system: "cpu gpu memory stats monitor"
        case .battery: "power charge"
        case .nowPlaying: "music spotify song player audio"
        case .note: "sticky memo text"
        case .photo: "picture image slideshow collage gallery"
        case .ambient: "animated art scene live"
        case .quote: "affirmation words motivation reminder poster text"
        case .countdown: "days event birthday trip"
        case .lockScreen: "iphone depth clock photo"
        case .vinyl: "record music spin"
        case .moon: "phases night lunar"
        case .daylight: "sun sky sunrise sunset"
        case .polaroids: "photos prints instant film"
        case .todo: "tasks checklist reminders list notes"
        case .focus: "pomodoro timer study productivity break"
        case .stopwatch: "timer lap time"
        case .shortcuts: "apps launcher links icons favorites"
        case .sticker: "star heart sparkle cute decoration emoji"
        case .neon: "neon sign glow light words text dark cyberpunk"
        case .terminal: "terminal hacker code cpu memory stats dark matrix neofetch"
        case .dots: "year progress days dots calendar minimal dark life"
        case .metric: "cpu memory ram disk storage network wifi battery health uptime status"
        case .date: "day today calendar"
        case .nextEvent: "meeting event calendar upcoming schedule"
        case .goals: "goals water daily targets rings"
        case .habits: "habits streak tracker routine daily"
        case .reading: "book reading pages progress"
        case .github: "github git code developer contributions pull requests issues ci actions repository"
        case .status: "status uptime api server health monitor ping"
        case .airQuality: "air quality aqi pollution pm2.5 smog"
        case .retroWindow: "retro mac macintosh classic 1984 vintage window"
        case .enso: "zen enso circle japanese minimal day"
        case .magazine: "magazine cover editorial vogue date headline"
        case .jersey: "football soccer shirt kit jersey number name club team"
        case .playerCard: "football soccer player card rating stats ultimate team goat legend"
        case .pitch: "football soccer pitch field tactics formation ball live"
        case .scoreboard: "football soccer match score kickoff countdown stadium game"
        case .milestone: "goals record stat number achievement trophy count"
        case .cassette: "cassette tape mixtape retro 90s 80s music reels"
        case .vhs: "vhs video tape camcorder retro 90s vintage film americana"
        case .visualizer: "visualizer audio music bars equalizer glow spectrum"
        case .ticket: "ticket concert tour gig show event match stub"
        case .wordArt: "word art chrome gold neon glitter fire ice holographic text script name"
        case .spiral: "spiral hypnotic hypnosis op art swirl vortex trippy black white illusion"
        case .charm: "charm chrome heart star cross gothic wings angel butterfly moon bow y2k metal silver pendant"
        case .label: "label perfume fragrance bottle luxury number no parfum name brand"
        case .aura: "aura energy glow gradient mood colors orb spiritual vibe"
        case .tarot: "tarot card daily reading fortune major arcana mystic witchy"
        case .zodiac: "zodiac star sign horoscope astrology constellation stars birthday"
        case .eightBall: "magic 8 ball eight fortune question answer yes no shake decide"
        case .candle: "candle flame fire cozy dark academia light calm flicker"
        }
    }

    /// The sizes it has layouts for.
    public var supportedSizes: [WidgetSize] {
        switch self {
        case .battery, .nowPlaying, .focus, .stopwatch, .date, .reading, .airQuality: [.small, .medium]
        case .magazine: [.small, .large]
        case .milestone, .ticket: [.small, .medium]
        case .label, .eightBall: [.small, .medium]
        case .pitch: [.medium, .large, .extraLarge]
        // Designed for the extra-large size too.
        case .clock, .weather, .system, .github: [.small, .medium, .large, .extraLarge]
        default: [.small, .medium, .large]
        }
    }

    /// Drawn straight onto the desktop, with no card behind it.
    public var isFreeform: Bool { [.polaroids, .sticker, .wordArt, .ticket, .charm].contains(self) }

    /// Kinds that paint their own backgrounds, so card styles don't apply.
    public var paintsOwnBackground: Bool {
        switch self {
        case .ambient, .vinyl, .moon, .daylight, .polaroids, .sticker, .note, .jersey, .playerCard, .pitch, .scoreboard,
             .cassette, .vhs, .visualizer, .ticket, .wordArt,
             .spiral, .charm, .label, .aura, .tarot, .zodiac, .eightBall, .candle: true
        default: false
        }
    }

    public var defaultSize: WidgetSize {
        switch self {
        case .clock, .nowPlaying, .photo, .ambient, .quote, .lockScreen, .vinyl, .daylight, .polaroids, .shortcuts,
             .neon, .terminal, .dots, .nextEvent, .goals, .habits, .github, .status, .retroWindow, .pitch, .scoreboard,
             .cassette, .vhs, .visualizer, .ticket, .wordArt, .zodiac: .medium
        case .magazine, .playerCard: .large
        default: .small
        }
    }
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

/// Settings for every kind of widget. Each kind reads only its own fields.
public struct WidgetOptions: Codable, Equatable, Sendable {
    public var clockFace: ClockFace = .digital
    public var use24Hour = false
    public var showSeconds = false
    /// The scenic clock offered by the cinematic Widgets studio.
    public var cinematicClock = false
    public var cinematicStyle = false
    /// Nil for the Mac's own time zone.
    public var timeZoneID: String?
    public var location: WeatherLocation?
    public var showEvents = true
    public var noteText = ""
    public var noteColor: NoteColor = .yellow
    // Photo
    public var images: [ImageSource] = []
    /// Seconds between photos; 0 shows only the first.
    public var slideshowInterval: Double = 0
    public var photoFilter: PhotoFilter = .none
    public var photoFrame: PhotoFrame = .fullBleed
    public var caption = ""
    // Art backgrounds and Live Scenes
    public var art = ArtPiece(style: .blobs, palette: .sunset)
    public var animateArt = true
    public var artSpeed = 1.0
    public var sceneOverlay: SceneOverlay = .time
    // Quote, Live Scene text, Countdown
    public var quoteSource: QuoteSource = .affirmations
    public var customText = ""
    public var textStyle: TextStyle = .classic
    public var countdownTitle = "Something good"
    public var countdownDate: Date?
    // Photo and mesh backgrounds
    /// The photo behind a widget with the Photo background.
    public var background: ImageSource?
    /// 0...1: from sharp to dreamily soft.
    public var backgroundBlur = 0.0
    /// Lock Screen: the photo's subject stands in front of the time.
    public var depthEffect = true
    // Theme colors
    /// Text color on the card; nil for black or white, whichever reads.
    public var ink: WidgetColor?
    /// Highlight color; nil for the tint (or the art's own accent).
    public var accent: WidgetColor?
    // To-Do
    public var listTitle = "to-do"
    public var showDone = true
    // Focus Timer and Stopwatch
    public var focusMinutes = 25.0
    public var breakMinutes = 5.0
    public var focus = FocusSession()
    public var stopwatch = StopwatchState()
    // Shortcuts
    public var shortcuts: [ShortcutItem] = ShortcutItem.starters
    /// Words under each icon.
    public var showLabels = true
    // Sticker
    public var sticker: StickerShape = .star
    public var stickerFinish: StickerFinish = .soft
    /// Emoji or a word to show instead of the shape.
    public var stickerText = ""
    /// Degrees; stickers look best a little crooked.
    public var stickerTilt = 0.0
    /// Neon Sign: now and then the tubes stutter.
    public var neonFlicker = true
    // Theme engine
    /// A `DesignTheme` id. When set, it draws the card, colors and type, and
    /// `material`, `tint` and `ink` are ignored.
    public var designTheme: String?
    public var appearance: WidgetAppearance = .auto
    /// 0 as the theme designs it, up to 1 for as see-through as it allows.
    public var transparency = 0.0
    public var refresh: RefreshPolicy = .balanced
    /// How much the theme's accent follows the wallpaper; nil for the theme's own choice.
    public var accentMode: WallpaperAdaptation?
    // System Metric
    public var metric: SystemMetric = .cpu
    // World clock
    public var worldZones: [String] = ["America/New_York", "Europe/London", "Asia/Tokyo"]
    // Daily Goals and Habit Tracker
    public var goals: [DailyGoal] = DailyGoal.starters
    /// The day the goals' progress belongs to ("2026-09-25"); older progress reads as zero.
    public var goalsDay = ""
    public var habits: [Habit] = Habit.starters
    // Reading Progress
    public var book = ReadingBook()
    // Developer
    public var github = GitHubConfig()
    public var endpoints: [StatusEndpoint] = StatusEndpoint.starters
    // Football and music
    public var player = PlayerDetails()
    public var match = MatchDetails()
    public var ticket = TicketDetails()
    public var milestone = MilestoneDetails()
    public var visualizer: VisualizerStyle = .bars
    public var wordArt: WordArtFinish = .chrome
    public var charm: CharmShape = .heart
    public var zodiac: ZodiacSign = .leo
    // Text and shape, for every widget
    /// This widget's own typeface; nil follows the desktop's (or its design theme's).
    public var font: WidgetFont?
    /// This widget's own corner roundness; nil follows the desktop's.
    public var cornerRadius: Double?
    public var textCase: WidgetTextCase = .asWritten
    /// The widget's built-in words renamed: its own text → what to show instead.
    public var renamedText: [String: String] = [:]
    /// A line of the person's own under the widget.
    public var footnote = ""
    public var footnoteStyle = FootnoteStyle()

    public init() {}

    /// What to show for one of the widget's built-in words.
    public func text(_ original: String) -> String {
        guard let renamed = renamedText[original], !renamed.trimmingCharacters(in: .whitespaces).isEmpty else { return original }
        return renamed
    }

    // Missing keys fall back to defaults, so saved layouts survive new options.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WidgetOptions()
        clockFace = (try? container.decodeIfPresent(ClockFace.self, forKey: .clockFace)) ?? defaults.clockFace
        use24Hour = (try? container.decodeIfPresent(Bool.self, forKey: .use24Hour)) ?? defaults.use24Hour
        showSeconds = (try? container.decodeIfPresent(Bool.self, forKey: .showSeconds)) ?? defaults.showSeconds
        cinematicClock = (try? container.decodeIfPresent(Bool.self, forKey: .cinematicClock)) ?? defaults.cinematicClock
        cinematicStyle = (try? container.decodeIfPresent(Bool.self, forKey: .cinematicStyle)) ?? defaults.cinematicStyle
        timeZoneID = try? container.decodeIfPresent(String.self, forKey: .timeZoneID)
        location = try? container.decodeIfPresent(WeatherLocation.self, forKey: .location)
        showEvents = (try? container.decodeIfPresent(Bool.self, forKey: .showEvents)) ?? defaults.showEvents
        noteText = (try? container.decodeIfPresent(String.self, forKey: .noteText)) ?? defaults.noteText
        noteColor = (try? container.decodeIfPresent(NoteColor.self, forKey: .noteColor)) ?? defaults.noteColor
        images = (try? container.decodeIfPresent(LossyList<ImageSource>.self, forKey: .images))?.elements ?? defaults.images
        slideshowInterval = (try? container.decodeIfPresent(Double.self, forKey: .slideshowInterval)) ?? defaults.slideshowInterval
        photoFilter = (try? container.decodeIfPresent(PhotoFilter.self, forKey: .photoFilter)) ?? defaults.photoFilter
        photoFrame = (try? container.decodeIfPresent(PhotoFrame.self, forKey: .photoFrame)) ?? defaults.photoFrame
        caption = (try? container.decodeIfPresent(String.self, forKey: .caption)) ?? defaults.caption
        art = (try? container.decodeIfPresent(ArtPiece.self, forKey: .art)) ?? defaults.art
        animateArt = (try? container.decodeIfPresent(Bool.self, forKey: .animateArt)) ?? defaults.animateArt
        artSpeed = (try? container.decodeIfPresent(Double.self, forKey: .artSpeed)) ?? defaults.artSpeed
        sceneOverlay = (try? container.decodeIfPresent(SceneOverlay.self, forKey: .sceneOverlay)) ?? defaults.sceneOverlay
        quoteSource = (try? container.decodeIfPresent(QuoteSource.self, forKey: .quoteSource)) ?? defaults.quoteSource
        customText = (try? container.decodeIfPresent(String.self, forKey: .customText)) ?? defaults.customText
        textStyle = (try? container.decodeIfPresent(TextStyle.self, forKey: .textStyle)) ?? defaults.textStyle
        countdownTitle = (try? container.decodeIfPresent(String.self, forKey: .countdownTitle)) ?? defaults.countdownTitle
        countdownDate = try? container.decodeIfPresent(Date.self, forKey: .countdownDate)
        background = try? container.decodeIfPresent(ImageSource.self, forKey: .background)
        backgroundBlur = (try? container.decodeIfPresent(Double.self, forKey: .backgroundBlur)) ?? defaults.backgroundBlur
        depthEffect = (try? container.decodeIfPresent(Bool.self, forKey: .depthEffect)) ?? defaults.depthEffect
        ink = try? container.decodeIfPresent(WidgetColor.self, forKey: .ink)
        accent = try? container.decodeIfPresent(WidgetColor.self, forKey: .accent)
        listTitle = (try? container.decodeIfPresent(String.self, forKey: .listTitle)) ?? defaults.listTitle
        showDone = (try? container.decodeIfPresent(Bool.self, forKey: .showDone)) ?? defaults.showDone
        focusMinutes = (try? container.decodeIfPresent(Double.self, forKey: .focusMinutes)) ?? defaults.focusMinutes
        breakMinutes = (try? container.decodeIfPresent(Double.self, forKey: .breakMinutes)) ?? defaults.breakMinutes
        focus = (try? container.decodeIfPresent(FocusSession.self, forKey: .focus)) ?? defaults.focus
        stopwatch = (try? container.decodeIfPresent(StopwatchState.self, forKey: .stopwatch)) ?? defaults.stopwatch
        shortcuts = (try? container.decodeIfPresent(LossyList<ShortcutItem>.self, forKey: .shortcuts))?.elements ?? defaults.shortcuts
        showLabels = (try? container.decodeIfPresent(Bool.self, forKey: .showLabels)) ?? defaults.showLabels
        sticker = (try? container.decodeIfPresent(StickerShape.self, forKey: .sticker)) ?? defaults.sticker
        stickerFinish = (try? container.decodeIfPresent(StickerFinish.self, forKey: .stickerFinish)) ?? defaults.stickerFinish
        stickerText = (try? container.decodeIfPresent(String.self, forKey: .stickerText)) ?? defaults.stickerText
        stickerTilt = (try? container.decodeIfPresent(Double.self, forKey: .stickerTilt)) ?? defaults.stickerTilt
        neonFlicker = (try? container.decodeIfPresent(Bool.self, forKey: .neonFlicker)) ?? defaults.neonFlicker
        designTheme = try? container.decodeIfPresent(String.self, forKey: .designTheme)
        appearance = (try? container.decodeIfPresent(WidgetAppearance.self, forKey: .appearance)) ?? defaults.appearance
        transparency = (try? container.decodeIfPresent(Double.self, forKey: .transparency)) ?? defaults.transparency
        refresh = (try? container.decodeIfPresent(RefreshPolicy.self, forKey: .refresh)) ?? defaults.refresh
        accentMode = try? container.decodeIfPresent(WallpaperAdaptation.self, forKey: .accentMode)
        metric = (try? container.decodeIfPresent(SystemMetric.self, forKey: .metric)) ?? defaults.metric
        worldZones = (try? container.decodeIfPresent([String].self, forKey: .worldZones)) ?? defaults.worldZones
        goals = (try? container.decodeIfPresent(LossyList<DailyGoal>.self, forKey: .goals))?.elements ?? defaults.goals
        goalsDay = (try? container.decodeIfPresent(String.self, forKey: .goalsDay)) ?? defaults.goalsDay
        habits = (try? container.decodeIfPresent(LossyList<Habit>.self, forKey: .habits))?.elements ?? defaults.habits
        book = (try? container.decodeIfPresent(ReadingBook.self, forKey: .book)) ?? defaults.book
        github = (try? container.decodeIfPresent(GitHubConfig.self, forKey: .github)) ?? defaults.github
        endpoints = (try? container.decodeIfPresent(LossyList<StatusEndpoint>.self, forKey: .endpoints))?.elements ?? defaults.endpoints
        player = (try? container.decodeIfPresent(PlayerDetails.self, forKey: .player)) ?? defaults.player
        match = (try? container.decodeIfPresent(MatchDetails.self, forKey: .match)) ?? defaults.match
        ticket = (try? container.decodeIfPresent(TicketDetails.self, forKey: .ticket)) ?? defaults.ticket
        milestone = (try? container.decodeIfPresent(MilestoneDetails.self, forKey: .milestone)) ?? defaults.milestone
        visualizer = (try? container.decodeIfPresent(VisualizerStyle.self, forKey: .visualizer)) ?? defaults.visualizer
        wordArt = (try? container.decodeIfPresent(WordArtFinish.self, forKey: .wordArt)) ?? defaults.wordArt
        charm = (try? container.decodeIfPresent(CharmShape.self, forKey: .charm)) ?? defaults.charm
        zodiac = (try? container.decodeIfPresent(ZodiacSign.self, forKey: .zodiac)) ?? defaults.zodiac
        font = try? container.decodeIfPresent(WidgetFont.self, forKey: .font)
        cornerRadius = try? container.decodeIfPresent(Double.self, forKey: .cornerRadius)
        textCase = (try? container.decodeIfPresent(WidgetTextCase.self, forKey: .textCase)) ?? defaults.textCase
        renamedText = (try? container.decodeIfPresent([String: String].self, forKey: .renamedText)) ?? defaults.renamedText
        footnote = (try? container.decodeIfPresent(String.self, forKey: .footnote)) ?? defaults.footnote
        footnoteStyle = (try? container.decodeIfPresent(FootnoteStyle.self, forKey: .footnoteStyle)) ?? defaults.footnoteStyle
    }
}

/// How a widget's words are cased.
public enum WidgetTextCase: String, Codable, CaseIterable, Identifiable, Sendable {
    case asWritten, uppercase, lowercase

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .asWritten: "As Written"
        case .uppercase: "UPPERCASE"
        case .lowercase: "lowercase"
        }
    }
}

/// How the line under a widget looks.
public struct FootnoteStyle: Codable, Equatable, Sendable {
    public enum Size: String, Codable, CaseIterable, Identifiable, Sendable {
        case small, medium, large
        public var id: String { rawValue }
        public var title: String { rawValue.capitalized }
        public var points: Double {
            switch self {
            case .small: 10
            case .medium: 11.5
            case .large: 13
            }
        }
    }

    public enum Alignment: String, Codable, CaseIterable, Identifiable, Sendable {
        case leading, center, trailing
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .leading: "Left"
            case .center: "Center"
            case .trailing: "Right"
            }
        }
    }

    public var size: Size = .medium
    public var alignment: Alignment = .center
    public var bold = true
    /// Nil is white with a soft shadow, readable on most wallpapers.
    public var color: WidgetColor?
    /// Nil follows the widget's own font.
    public var font: WidgetFont?

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FootnoteStyle()
        size = (try? container.decodeIfPresent(Size.self, forKey: .size)) ?? defaults.size
        alignment = (try? container.decodeIfPresent(Alignment.self, forKey: .alignment)) ?? defaults.alignment
        bold = (try? container.decodeIfPresent(Bool.self, forKey: .bold)) ?? defaults.bold
        color = try? container.decodeIfPresent(WidgetColor.self, forKey: .color)
        font = try? container.decodeIfPresent(WidgetFont.self, forKey: .font)
    }
}

public struct WidgetInstance: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: WidgetKind
    public var size: WidgetSize
    public var material: WidgetMaterial
    public var tint: WidgetColor
    /// The display it's on: its stable id, which decides (see `DisplayIdentity`),
    /// and its name, the fallback for layouts saved before ids and for older
    /// versions. Widgets whose display is disconnected show on the primary
    /// screen until it's back.
    public var screenID: String?
    public var screenName: String?
    /// Top-left corner, measured from the top-left of the screen's visible area.
    public var offset: CGPoint
    public var options: WidgetOptions
    /// How much larger or smaller than its size's own dimensions it's drawn,
    /// from dragging its corner on the desktop. Its layout stays the one that
    /// size was designed with; 1 for a widget never resized.
    public var scale: Double
    /// Height relative to width once scaled: 1 keeps the layout's own shape,
    /// other values stretch it taller or shorter (a free-form resize).
    public var stretch: Double

    public static let scaleRange: ClosedRange<Double> = 0.4...3
    public static let stretchRange: ClosedRange<Double> = 0.1...6

    /// What it covers on the desktop, in layout points.
    public var footprint: CGSize {
        CGSize(width: size.dimensions.width * scale, height: size.dimensions.height * scale * stretch)
    }

    public init(kind: WidgetKind, size: WidgetSize? = nil, screenName: String? = nil, offset: CGPoint = .zero) {
        id = UUID()
        self.kind = kind
        self.size = size ?? kind.defaultSize
        tint = WidgetColor.presets[0]
        self.screenName = screenName
        self.offset = offset
        options = WidgetOptions()
        scale = 1
        stretch = 1
        switch kind {
        case .weather:
            material = .tinted
        case .ambient:
            material = .art
            options.art = ArtPiece(style: .aurora, palette: .aurora)
        case .quote:
            material = .art
            options.art = ArtPiece(style: .blobs, palette: .lavender)
            options.animateArt = false
        case .countdown:
            material = .art
            options.art = ArtPiece(style: .sunset, palette: .peach)
            options.animateArt = false
            options.countdownDate = Calendar.current.date(byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: .now))
        case .photo:
            material = .glass
            options.images = [.art(ArtPiece(style: .dunes, palette: .desert))]
        case .clock:
            material = .photo
            options.background = CuratedBackgrounds.photo(id: "830").map(ImageSource.web)
        case .lockScreen:
            material = .photo
            options.clockFace = .stacked
            options.background = CuratedBackgrounds.photo(id: "65").map(ImageSource.web)
        case .calendar:
            material = .mesh
            options.art = ArtPiece(style: .aurora, palette: .midnight)
        case .vinyl, .moon, .daylight:
            // They paint their own backgrounds.
            material = .dark
        case .todo:
            // Cream paper with soft brown ink.
            material = .paper
            tint = WidgetColor(hex: 0xF4EEE4)
            options.ink = WidgetColor(hex: 0x4A4039)
            options.accent = WidgetColor(hex: 0xB08D6E)
        case .focus:
            material = .frosted
            tint = WidgetColor(hex: 0x1E1B22)
            options.accent = WidgetColor(hex: 0xF7C6D9)
        case .stopwatch:
            material = .paper
            tint = WidgetColor(hex: 0xEFECE8)
            options.ink = WidgetColor(hex: 0x3A3633)
            options.accent = WidgetColor(hex: 0x3A3633)
        case .shortcuts:
            // Icons right on the wallpaper.
            material = .clear
            tint = WidgetColor(hex: 0xFAFAFA)
        case .sticker:
            material = .clear
            tint = WidgetColor(hex: 0xBFD4FF)
            options.stickerTilt = -8
        case .neon:
            // Tubes glowing right on the wallpaper.
            material = .clear
            tint = WidgetColor(hex: 0xFF3CAC)
            options.customText = "good vibes only"
            options.textStyle = .script
        case .terminal:
            material = .paper
            tint = WidgetColor(hex: 0x0A0C0A)
            options.ink = WidgetColor(hex: 0x39FF88)
            options.accent = WidgetColor(hex: 0x39FF88)
        case .dots:
            material = .frosted
            tint = WidgetColor(hex: 0x121216)
            options.ink = WidgetColor(hex: 0xF2F2F2)
            options.accent = WidgetColor(hex: 0xFFD23F)
        case .metric, .date, .nextEvent, .goals, .habits, .reading, .github, .status, .airQuality:
            // The everyday widgets start in the native look.
            material = .glass
            options.designTheme = DesignTheme.native.id
        case .retroWindow:
            material = .glass
            options.designTheme = DesignTheme.retroMac.id
        case .enso:
            material = .glass
            options.designTheme = DesignTheme.zen.id
        case .magazine:
            material = .glass
            options.designTheme = DesignTheme.editorial.id
        case .polaroids:
            // Prints lying on the desktop, with no card behind them.
            material = .dark
            options.images = CuratedBackgrounds.polaroidStarters.map(ImageSource.web)
            options.slideshowInterval = 0
        case .jersey, .playerCard, .pitch, .scoreboard, .ticket:
            // They paint their own backgrounds.
            material = .dark
        case .milestone:
            material = .frosted
            tint = WidgetColor(hex: 0x0E0C0A)
            options.ink = WidgetColor(hex: 0xF6F1E7)
            options.accent = WidgetColor(hex: 0xE8C15A)
        case .cassette:
            material = .dark
            tint = WidgetColor(hex: 0xFF5C8A)
            options.customText = "summer mix"
        case .vhs:
            material = .dark
            options.images = CuratedBackgrounds.collection("Palm Sunsets").prefix(1).map(ImageSource.web)
            options.caption = "SUMMER 1996"
        case .visualizer:
            material = .dark
            tint = WidgetColor(hex: 0x7CFF6B)
        case .wordArt:
            // Letters straight on the wallpaper.
            material = .clear
            tint = WidgetColor(hex: 0xFF3CAC)
            options.customText = "Legend"
            options.textStyle = .script
        case .spiral:
            material = .dark
            tint = WidgetColor(hex: 0x0B0B0C)
            options.ink = WidgetColor(hex: 0xF4F1EA)
        case .charm:
            // Metal straight on the wallpaper.
            material = .clear
            tint = WidgetColor(hex: 0xDDE3F0)
        case .label:
            material = .dark
            tint = WidgetColor(hex: 0xF3EDE2)
            options.ink = WidgetColor(hex: 0x1A1714)
            options.customText = "MIDNIGHT"
            options.caption = "Nº 07 · EAU DE NUIT"
        case .aura:
            material = .dark
            tint = WidgetColor(hex: 0x0C0A12)
        case .tarot:
            material = .dark
            tint = WidgetColor(hex: 0x0F0B16)
            options.accent = WidgetColor(hex: 0xE8C15A)
        case .zodiac:
            material = .dark
            tint = WidgetColor(hex: 0x070A1A)
            options.accent = WidgetColor(hex: 0xCFE3FF)
            options.zodiac = ZodiacSign.sign(on: .now)
        case .eightBall:
            material = .dark
            tint = WidgetColor(hex: 0x0B0B12)
            options.accent = WidgetColor(hex: 0x3D5AFE)
        case .candle:
            material = .dark
            tint = WidgetColor(hex: 0x110C08)
            options.customText = "light a candle, make a wish"
        default:
            material = .glass
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(WidgetKind.self, forKey: .kind)
        size = (try? container.decode(WidgetSize.self, forKey: .size)) ?? kind.defaultSize
        material = (try? container.decode(WidgetMaterial.self, forKey: .material)) ?? .glass
        tint = (try? container.decode(WidgetColor.self, forKey: .tint)) ?? WidgetColor.presets[0]
        screenID = try? container.decodeIfPresent(String.self, forKey: .screenID)
        screenName = try? container.decodeIfPresent(String.self, forKey: .screenName)
        offset = (try? container.decode(CGPoint.self, forKey: .offset)) ?? .zero
        options = (try? container.decode(WidgetOptions.self, forKey: .options)) ?? WidgetOptions()
        // Layouts saved before resizing existed have none: their own size.
        let saved = (try? container.decodeIfPresent(Double.self, forKey: .scale)) ?? 1
        scale = saved.isFinite ? min(max(saved, Self.scaleRange.lowerBound), Self.scaleRange.upperBound) : 1
        let stretched = (try? container.decodeIfPresent(Double.self, forKey: .stretch)) ?? 1
        stretch = stretched.isFinite ? min(max(stretched, Self.stretchRange.lowerBound), Self.stretchRange.upperBound) : 1
    }
}

/// Placement math, in the coordinates `WidgetInstance.offset` uses: origin at
/// the top-left of the screen's visible area, y growing downward.
public enum WidgetLayout {
    /// Gap between widgets, as on macOS.
    public static let spacing: CGFloat = 16
    /// Distance from the edges of the visible area.
    public static let margin: CGFloat = 8
    public static let grid: CGFloat = 8

    /// Keeps a widget of `size` fully inside `bounds`, without moving it otherwise.
    public static func clamp(_ offset: CGPoint, size: CGSize, within bounds: CGSize) -> CGPoint {
        CGPoint(x: min(max(offset.x, 0), max(bounds.width - size.width, 0)),
                y: min(max(offset.y, 0), max(bounds.height - size.height, 0)))
    }

    /// Widgets moved and sized so their arrangement fills `bounds` (inside the
    /// margins, as far as `range` allows) and sits centered, keeping every gap
    /// in proportion. Offsets stay in layout points; `scale` is how much larger
    /// than that to draw everything (position and size alike).
    public static func fitted(_ widgets: [WidgetInstance], in bounds: CGSize,
                              range: ClosedRange<Double>) -> (widgets: [WidgetInstance], scale: Double) {
        guard let first = widgets.first else { return (widgets, 1) }
        let box = widgets.dropFirst().reduce(CGRect(origin: first.offset, size: first.footprint)) {
            $0.union(CGRect(origin: $1.offset, size: $1.footprint))
        }
        guard box.width > 0, box.height > 0 else { return (widgets, 1) }
        let fits = Double(min((bounds.width - 2 * margin) / box.width, (bounds.height - 2 * margin) / box.height))
        let scale = min(max(fits, range.lowerBound), range.upperBound)
        // Centered on screen, in screen points; then back into layout points.
        let factor = CGFloat(scale)
        let origin = CGPoint(x: max((bounds.width - box.width * factor) / 2, 0) / factor,
                             y: max((bounds.height - box.height * factor) / 2, 0) / factor)
        let moved = widgets.map { widget in
            var widget = widget
            widget.offset = CGPoint(x: widget.offset.x - box.minX + origin.x, y: widget.offset.y - box.minY + origin.y)
            return widget
        }
        return (moved, scale)
    }

    /// Rounds to the grid and keeps the widget fully inside `bounds`.
    public static func snap(_ offset: CGPoint, size: CGSize, within bounds: CGSize) -> CGPoint {
        func place(_ value: CGFloat, length: CGFloat, limit: CGFloat) -> CGFloat {
            let snapped = (value / grid).rounded() * grid
            return min(max(snapped, 0), max(limit - length, 0))
        }
        return CGPoint(x: place(offset.x, length: size.width, limit: bounds.width),
                       y: place(offset.y, length: size.height, limit: bounds.height))
    }

    /// The first spot that keeps `spacing` clear of every occupied rect,
    /// filling columns from the left as macOS does, which keeps widgets away
    /// from desktop icons in the top-right. Falls back to the top-left corner.
    public static func freeOffset(for size: CGSize, avoiding occupied: [CGRect], within bounds: CGSize) -> CGPoint {
        let clearance = spacing - 0.5
        var x = margin
        while x + size.width <= bounds.width - margin {
            var y = margin
            while y + size.height <= bounds.height - margin {
                let candidate = CGRect(origin: CGPoint(x: x, y: y), size: size)
                if !occupied.contains(where: { $0.insetBy(dx: -clearance, dy: -clearance).intersects(candidate) }) {
                    return candidate.origin
                }
                y += grid
            }
            x += grid
        }
        return CGPoint(x: margin, y: margin)
    }

    /// What a new user sees: a clock with a calendar and system stats below it.
    public static func starterSet(screenName: String?) -> [WidgetInstance] {
        let medium = WidgetSize.medium.dimensions
        let small = WidgetSize.small.dimensions
        let secondRow = margin + medium.height + spacing
        return [
            WidgetInstance(kind: .clock, size: .medium, screenName: screenName,
                           offset: CGPoint(x: margin, y: margin)),
            WidgetInstance(kind: .calendar, size: .small, screenName: screenName,
                           offset: CGPoint(x: margin, y: secondRow)),
            WidgetInstance(kind: .system, size: .small, screenName: screenName,
                           offset: CGPoint(x: margin + small.width + spacing, y: secondRow)),
        ]
    }
}

/// What a System Metric widget shows.
public enum SystemMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case cpu, memory, disk, storage, network, wifi, battery, batteryHealth, uptime, status

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk Activity"
        case .storage: "Storage"
        case .network: "Network"
        case .wifi: "Wi-Fi"
        case .battery: "Battery"
        case .batteryHealth: "Battery Health"
        case .uptime: "Uptime"
        case .status: "System Status"
        }
    }

    public var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .storage: "externaldrive.fill"
        case .network: "arrow.up.arrow.down"
        case .wifi: "wifi"
        case .battery: "battery.75percent"
        case .batteryHealth: "heart.text.square"
        case .uptime: "clock.arrow.circlepath"
        case .status: "checkmark.shield"
        }
    }
}

/// One of a few counts to reach today: glasses of water, pages, minutes.
public struct DailyGoal: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var symbol: String
    public var unit: String
    public var target: Int
    public var progress: Int

    public init(id: UUID = UUID(), title: String, symbol: String, unit: String, target: Int, progress: Int = 0) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.unit = unit
        self.target = target
        self.progress = progress
    }

    public var fraction: Double { target > 0 ? min(Double(progress) / Double(target), 1) : 0 }

    /// Fixed ids, so default options always compare equal.
    public static let starters: [DailyGoal] = [
        ("Water", "drop.fill", "glasses", 8), ("Move", "figure.walk", "min", 30), ("Read", "book.fill", "pages", 20),
    ].enumerated().map { index, goal in
        DailyGoal(id: UUID(uuidString: String(format: "60A10000-0000-4000-8000-%012d", index))!,
                  title: goal.0, symbol: goal.1, unit: goal.2, target: goal.3)
    }
}

/// Something to do every day, with the days it was done.
public struct Habit: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var symbol: String
    /// Days done, as "2026-09-25".
    public var done: [String]

    public init(id: UUID = UUID(), title: String, symbol: String, done: [String] = []) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.done = done
    }

    public func isDone(on date: Date, calendar: Calendar = .current) -> Bool {
        done.contains(Self.key(date, calendar: calendar))
    }

    /// Days in a row up to `date`; today not yet done doesn't break it.
    public func streak(until date: Date, calendar: Calendar = .current) -> Int {
        let days = Set(done)
        var day = days.contains(Self.key(date, calendar: calendar)) ? date : calendar.date(byAdding: .day, value: -1, to: date)!
        var count = 0
        while days.contains(Self.key(day, calendar: calendar)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    public mutating func toggle(on date: Date, calendar: Calendar = .current) {
        let key = Self.key(date, calendar: calendar)
        if let index = done.firstIndex(of: key) {
            done.remove(at: index)
        } else {
            done.append(key)
            // Only the last year matters for streaks and the grid.
            if done.count > 400 { done.removeFirst(done.count - 400) }
        }
    }

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static let starters: [Habit] = [
        ("Meditate", "leaf.fill"), ("Workout", "figure.run"), ("Journal", "pencil.line"), ("Sleep by 11", "moon.zzz.fill"),
    ].enumerated().map { index, habit in
        Habit(id: UUID(uuidString: String(format: "4AB10000-0000-4000-8000-%012d", index))!, title: habit.0, symbol: habit.1)
    }
}

/// The book being read, and how far.
public struct ReadingBook: Codable, Hashable, Sendable {
    public var title = "The Midnight Library"
    public var author = "Matt Haig"
    public var page = 112
    public var pages = 288
    /// The cover's color.
    public var color = WidgetColor(hex: 0x2F4B7C)

    public init() {}

    public var fraction: Double { pages > 0 ? min(max(Double(page) / Double(pages), 0), 1) : 0 }
}

/// What a GitHub widget shows.
public enum GitHubMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case contributions, activity, pullRequests, issues, repository, actions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .contributions: "Contributions"
        case .activity: "Activity"
        case .pullRequests: "Pull Requests"
        case .issues: "Issues"
        case .repository: "Repository"
        case .actions: "CI/CD"
        }
    }

    /// Whether it needs a repository ("owner/name") rather than a user.
    public var needsRepository: Bool { self == .repository || self == .actions }
}

public struct GitHubConfig: Codable, Hashable, Sendable {
    public var mode: GitHubMode = .contributions
    /// A GitHub username.
    public var user = ""
    /// "owner/name".
    public var repository = ""

    public init(mode: GitHubMode = .contributions, user: String = "", repository: String = "") {
        self.mode = mode
        self.user = user
        self.repository = repository
    }
}

/// A site or API a Status widget checks.
public struct StatusEndpoint: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var url: String

    public init(id: UUID = UUID(), name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }

    public static let starters: [StatusEndpoint] = [
        ("GitHub", "https://www.githubstatus.com/api/v2/status.json"),
        ("Apple", "https://www.apple.com"),
        ("Open-Meteo", "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&current=temperature_2m"),
    ].enumerated().map { index, endpoint in
        StatusEndpoint(id: UUID(uuidString: String(format: "57A70000-0000-4000-8000-%012d", index))!, name: endpoint.0, url: endpoint.1)
    }
}
