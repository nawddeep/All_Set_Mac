import Foundation

/// One widget in the gallery: a kind, set up for a purpose. Several entries
/// can share a kind ("CPU" and "Wi-Fi" are both System Metric), so adding a
/// widget means a view for its kind and an entry here, and nothing else.
public struct CatalogEntry: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let symbol: String
    public let category: WidgetCategory
    public let kind: WidgetKind
    public let keywords: String
    /// Sizes it's designed for; the kind's when nil.
    private let onlySizes: [WidgetSize]?
    private let startingSize: WidgetSize?
    private let configure: @Sendable (inout WidgetInstance) -> Void

    init(_ id: String, _ kind: WidgetKind, _ category: WidgetCategory, title: String? = nil, summary: String? = nil,
         symbol: String? = nil, keywords: String = "", sizes: [WidgetSize]? = nil, size: WidgetSize? = nil,
         configure: @escaping @Sendable (inout WidgetInstance) -> Void = { _ in }) {
        self.id = id
        self.kind = kind
        self.category = category
        self.title = title ?? kind.title
        self.summary = summary ?? kind.summary
        self.symbol = symbol ?? kind.symbol
        self.keywords = keywords + " " + kind.keywords
        onlySizes = sizes
        startingSize = size
        self.configure = configure
    }

    public var sizes: [WidgetSize] { onlySizes ?? kind.supportedSizes }
    public var defaultSize: WidgetSize { startingSize ?? (sizes.contains(kind.defaultSize) ? kind.defaultSize : sizes[0]) }

    /// A new widget of this entry, ready for the desktop.
    public func make(size: WidgetSize? = nil) -> WidgetInstance {
        var instance = WidgetInstance(kind: kind, size: size ?? defaultSize)
        configure(&instance)
        return instance
    }

    /// Everything the gallery search looks through.
    public var searchText: String { "\(title) \(summary) \(keywords) \(category.title)" }
}

public enum WidgetCatalog {
    public static func entries(in category: WidgetCategory) -> [CatalogEntry] {
        entries.filter { $0.category == category }
    }

    public static func entry(_ id: String) -> CatalogEntry? { entries.first { $0.id == id } }

    public static let entries: [CatalogEntry] = time + productivity + system + developer + lifestyle + aesthetic + football + music + mystic

    private static func face(_ face: ClockFace) -> @Sendable (inout WidgetInstance) -> Void {
        { $0.options.clockFace = face }
    }

    private static func metric(_ metric: SystemMetric) -> @Sendable (inout WidgetInstance) -> Void {
        { $0.options.metric = metric }
    }

    private static func github(_ mode: GitHubMode) -> @Sendable (inout WidgetInstance) -> Void {
        { $0.options.github.mode = mode }
    }

    static let time: [CatalogEntry] = [
        CatalogEntry("digitalClock", .clock, .time, title: "Digital Clock", summary: "The time and date, crisp and simple",
                     keywords: "digital", configure: face(.digital)),
        CatalogEntry("minimalClock", .clock, .time, title: "Minimal Clock", summary: "Just the time, thin and large",
                     symbol: "clock", keywords: "minimal thin", configure: { widget in
                         widget.options.clockFace = .minimal
                         widget.material = .glass
                         widget.options.designTheme = DesignTheme.native.id
                     }),
        CatalogEntry("analogClock", .clock, .time, title: "Analog Clock", summary: "A watch face with ticking hands",
                     symbol: "clock.circle", keywords: "analog watch", configure: face(.analog)),
        CatalogEntry("worldClock", .clock, .time, title: "World Clock", summary: "Several cities at a glance",
                     symbol: "globe", keywords: "world time zones cities", configure: { widget in
                         widget.options.clockFace = .world
                         widget.material = .glass
                         widget.options.designTheme = DesignTheme.native.id
                     }),
        CatalogEntry("flipClock", .clock, .time, title: "Flip Clock", summary: "Split-flap tiles, like an airport board",
                     symbol: "rectangle.split.2x1", keywords: "flip retro", configure: face(.flip)),
        CatalogEntry("date", .date, .time),
        CatalogEntry("countdown", .countdown, .time),
        CatalogEntry("stopwatch", .stopwatch, .time),
        CatalogEntry("yearDots", .dots, .time),
    ]

    static let productivity: [CatalogEntry] = [
        CatalogEntry("calendar", .calendar, .productivity),
        CatalogEntry("nextEvent", .nextEvent, .productivity),
        CatalogEntry("todo", .todo, .productivity),
        CatalogEntry("focusTimer", .focus, .productivity, title: "Focus Timer", summary: "Long, deep-work sessions",
                     symbol: "brain.head.profile", keywords: "deep work concentrate", configure: { widget in
                         widget.options.focusMinutes = 50
                         widget.options.breakMinutes = 10
                     }),
        CatalogEntry("pomodoro", .focus, .productivity, title: "Pomodoro", summary: "25 minutes on, 5 off, four times",
                     symbol: "timer", keywords: "pomodoro tomato"),
        CatalogEntry("goals", .goals, .productivity),
        CatalogEntry("habits", .habits, .productivity),
        CatalogEntry("notes", .note, .productivity, title: "Notes"),
        CatalogEntry("shortcuts", .shortcuts, .productivity),
    ]

    static let system: [CatalogEntry] = [
        CatalogEntry("systemMonitor", .system, .system, title: "System Monitor", summary: "CPU, GPU, memory and what's using them",
                     keywords: "monitor overview activity"),
        CatalogEntry("cpu", .metric, .system, title: "CPU", summary: "Processor load, with every core",
                     symbol: SystemMetric.cpu.symbol, configure: metric(.cpu)),
        CatalogEntry("memory", .metric, .system, title: "Memory", summary: "RAM in use and memory pressure",
                     symbol: SystemMetric.memory.symbol, configure: metric(.memory)),
        CatalogEntry("disk", .metric, .system, title: "Disk", summary: "Reads and writes, live",
                     symbol: SystemMetric.disk.symbol, configure: metric(.disk)),
        CatalogEntry("storage", .metric, .system, title: "Storage", summary: "How much space is left",
                     symbol: SystemMetric.storage.symbol, configure: metric(.storage)),
        CatalogEntry("network", .metric, .system, title: "Network", summary: "Download and upload speed",
                     symbol: SystemMetric.network.symbol, configure: metric(.network)),
        CatalogEntry("wifi", .metric, .system, title: "Wi-Fi", summary: "Signal strength and speed",
                     symbol: SystemMetric.wifi.symbol, configure: metric(.wifi)),
        CatalogEntry("battery", .battery, .system),
        CatalogEntry("batteryHealth", .metric, .system, title: "Battery Health", summary: "Capacity, cycles and condition",
                     symbol: SystemMetric.batteryHealth.symbol, configure: metric(.batteryHealth)),
        CatalogEntry("uptime", .metric, .system, title: "Uptime", summary: "How long since the last restart",
                     symbol: SystemMetric.uptime.symbol, sizes: [.small, .medium], configure: metric(.uptime)),
        CatalogEntry("systemStatus", .metric, .system, title: "System Status", summary: "Is everything all right? At a glance",
                     symbol: SystemMetric.status.symbol, configure: metric(.status)),
        CatalogEntry("terminal", .terminal, .system),
    ]

    static let developer: [CatalogEntry] = [
        CatalogEntry("githubContributions", .github, .developer, title: "GitHub Contributions",
                     summary: "Your contribution graph", symbol: "square.grid.3x3.fill", configure: github(.contributions)),
        CatalogEntry("githubActivity", .github, .developer, title: "GitHub Activity",
                     summary: "Your latest pushes, PRs and stars", symbol: "bolt.horizontal.fill", configure: github(.activity)),
        CatalogEntry("pullRequests", .github, .developer, title: "Pull Requests", summary: "Open pull requests you wrote",
                     symbol: "arrow.triangle.pull", sizes: [.small, .medium, .large], configure: github(.pullRequests)),
        CatalogEntry("issues", .github, .developer, title: "Issues", summary: "Open issues assigned to you",
                     symbol: "smallcircle.filled.circle", sizes: [.small, .medium, .large], configure: github(.issues)),
        CatalogEntry("repository", .github, .developer, title: "Repository Status", summary: "Stars, issues and the last push",
                     symbol: "shippingbox.fill", sizes: [.small, .medium, .large], configure: github(.repository)),
        CatalogEntry("ciStatus", .github, .developer, title: "CI/CD Status", summary: "GitHub Actions runs, passing or not",
                     symbol: "checkmark.circle.badge.xmark", sizes: [.small, .medium, .large], configure: github(.actions)),
        CatalogEntry("apiStatus", .status, .developer, title: "API Status", summary: "Is the API up, and how fast",
                     symbol: "network", keywords: "api endpoint"),
        CatalogEntry("serverStatus", .status, .developer, title: "Server Status", summary: "Your servers' health and latency",
                     symbol: "server.rack", keywords: "server host", configure: { widget in
                         widget.options.endpoints = [
                             StatusEndpoint(id: UUID(uuidString: "57A70000-0000-4000-8000-000000000010")!, name: "Cloudflare", url: "https://1.1.1.1"),
                             StatusEndpoint(id: UUID(uuidString: "57A70000-0000-4000-8000-000000000011")!, name: "Google", url: "https://www.google.com"),
                         ]
                     }),
    ]

    static let lifestyle: [CatalogEntry] = [
        CatalogEntry("weather", .weather, .lifestyle),
        CatalogEntry("airQuality", .airQuality, .lifestyle),
        CatalogEntry("sunriseSunset", .daylight, .lifestyle, title: "Sunrise & Sunset", keywords: "sunrise sunset"),
        CatalogEntry("moon", .moon, .lifestyle, title: "Moon Phase"),
        CatalogEntry("music", .nowPlaying, .lifestyle, title: "Music"),
        CatalogEntry("quote", .quote, .lifestyle),
        CatalogEntry("photo", .photo, .lifestyle),
        CatalogEntry("reading", .reading, .lifestyle),
    ]

    static let aesthetic: [CatalogEntry] = [
        CatalogEntry("classicMac", .retroWindow, .aesthetic),
        CatalogEntry("enso", .enso, .aesthetic),
        CatalogEntry("magazine", .magazine, .aesthetic),
        CatalogEntry("posterQuote", .quote, .aesthetic, title: "Poster", summary: "Huge words straight on the wallpaper",
                     symbol: "textformat.size.larger", keywords: "poster motivation", size: .large, configure: { widget in
                         widget.material = .clear
                         widget.options.quoteSource = .custom
                         widget.options.customText = "Good things\nare coming."
                         widget.options.caption = "Daily Reminder"
                         widget.options.textStyle = .poster
                         widget.options.ink = WidgetColor(red: 1, green: 1, blue: 1)
                     }),
        CatalogEntry("neon", .neon, .aesthetic),
        CatalogEntry("sticker", .sticker, .aesthetic),
        CatalogEntry("polaroids", .polaroids, .aesthetic),
        CatalogEntry("lockScreen", .lockScreen, .aesthetic),
        CatalogEntry("liveScene", .ambient, .aesthetic),
        CatalogEntry("vinyl", .vinyl, .aesthetic),
        CatalogEntry("wordArt", .wordArt, .aesthetic, title: "Chrome Words", summary: "Your words in liquid chrome"),
        CatalogEntry("goldScript", .wordArt, .aesthetic, title: "Gold Script", summary: "A name in gold foil script",
                     symbol: "signature", keywords: "gold script name signature luxury", configure: { widget in
                         widget.options.wordArt = .gold
                         widget.options.customText = "Angel"
                     }),
        CatalogEntry("neonWord", .wordArt, .aesthetic, title: "Neon Word", summary: "A word lit like a sign",
                     symbol: "lightbulb.max.fill", keywords: "neon glow sign word", configure: { widget in
                         widget.options.wordArt = .neon
                         widget.options.customText = "lust for life"
                         widget.tint = WidgetColor(hex: 0x4DD8FF)
                     }),
        CatalogEntry("glitterWord", .wordArt, .aesthetic, title: "Glitter Word", summary: "Sparkling letters that twinkle",
                     symbol: "sparkles", keywords: "glitter sparkle y2k baddie pink", configure: { widget in
                         widget.options.wordArt = .glitter
                         widget.options.customText = "Babe"
                         widget.options.textStyle = .chunky
                         widget.tint = WidgetColor(hex: 0xFF5FA2)
                     }),
        CatalogEntry("spiral", .spiral, .aesthetic, title: "Hypnotic Spiral"),
        CatalogEntry("redSpiral", .spiral, .aesthetic, title: "Red Spiral", summary: "A slow red-and-black vortex",
                     keywords: "red dark villain", configure: { widget in
                         widget.tint = WidgetColor(hex: 0x120405)
                         widget.options.ink = WidgetColor(hex: 0xE0233B)
                     }),
        CatalogEntry("chromeHeart", .charm, .aesthetic, title: "Chrome Heart", summary: "A puffy chrome heart that catches the light"),
        CatalogEntry("angelWings", .charm, .aesthetic, title: "Angel Wings", summary: "Silver wings, for your angelic era",
                     symbol: "bird.fill", keywords: "angel angelic heaven", configure: { $0.options.charm = .wings }),
        CatalogEntry("gothicCross", .charm, .aesthetic, title: "Gothic Cross", summary: "A chrome cross with flared ends",
                     symbol: "cross.fill", keywords: "gothic goth grunge rock", configure: { $0.options.charm = .cross }),
        CatalogEntry("chromeButterfly", .charm, .aesthetic, title: "Chrome Butterfly", summary: "A silver butterfly, straight from 2003",
                     symbol: "leaf.fill", keywords: "butterfly y2k", configure: { $0.options.charm = .butterfly }),
        CatalogEntry("perfumeLabel", .label, .aesthetic, title: "Perfume Label"),
        CatalogEntry("noirLabel", .label, .aesthetic, title: "Noir Label", summary: "Your name on a black-and-gold label",
                     keywords: "noir black gold luxe", configure: { widget in
                         widget.tint = WidgetColor(hex: 0x0E0D0C)
                         widget.options.ink = WidgetColor(hex: 0xE8C77A)
                         widget.options.customText = "DIVA"
                         widget.options.caption = "Nº 01 · EXTRAIT DE NUIT"
                     }),
    ]
}

extension WidgetCatalog {
    private static func kit(_ name: String, _ number: Int, _ preset: String, tagline: String = "") -> @Sendable (inout WidgetInstance) -> Void {
        { widget in
            widget.options.player.name = name
            widget.options.player.number = number
            widget.options.player.tagline = tagline
            if let kit = KitPreset.all.first(where: { $0.title == preset }) { widget.options.player.apply(kit) }
        }
    }

    static let football: [CatalogEntry] = [
        CatalogEntry("shirt", .jersey, .football, configure: kit("LEGEND", 7, "Red & Green", tagline: "Dream big")),
        CatalogEntry("stripedShirt", .jersey, .football, title: "Striped Shirt", summary: "Sky-blue stripes and a number ten",
                     keywords: "stripes sky blue ten", configure: kit("MAESTRO", 10, "Sky Stripes", tagline: "Pure magic")),
        CatalogEntry("canaryShirt", .jersey, .football, title: "Canary Shirt", summary: "Yellow and green, made for flair",
                     keywords: "yellow green samba flair ten", configure: kit("REI", 10, "Canary", tagline: "Joga bonito")),
        CatalogEntry("playerCard", .playerCard, .football),
        CatalogEntry("legendCard", .playerCard, .football, title: "Legend Card", summary: "Pearl foil for the all-time greats",
                     symbol: "crown.fill", keywords: "legend icon goat pearl", configure: { widget in
                         widget.options.player.finish = .legend
                         widget.options.player.rating = 98
                         widget.options.player.name = "THE GOAT"
                         widget.options.player.stats = [92, 96, 94, 97, 40, 80]
                     }),
        CatalogEntry("neonCard", .playerCard, .football, title: "Neon Card", summary: "Dark glass lit in your team's color",
                     symbol: "bolt.fill", keywords: "neon night glow", configure: { widget in
                         widget.options.player.finish = .neon
                         widget.options.player.name = "NIGHT SHIFT"
                         if let kit = KitPreset.all.first(where: { $0.title == "Pink & Black" }) { widget.options.player.apply(kit) }
                     }),
        CatalogEntry("tacticsBoard", .pitch, .football, configure: { widget in
            widget.options.match.home = "POR"
            widget.options.match.away = "ARG"
            widget.options.match.competition = "FRIENDLY"
            widget.options.match.kickoff = Calendar.current.date(byAdding: .day, value: 3, to: .now)
        }),
        CatalogEntry("scoreboard", .scoreboard, .football, configure: { widget in
            widget.options.match.home = "POR"
            widget.options.match.away = "ARG"
            widget.options.match.awayColor = WidgetColor(hex: 0x75AADB)
            widget.options.match.competition = "FRIENDLY"
            widget.options.match.kickoff = Calendar.current.date(byAdding: .day, value: 3, to: .now)
        }),
        CatalogEntry("finalScore", .scoreboard, .football, title: "Final Score", summary: "The result you'll never forget",
                     symbol: "flag.checkered", keywords: "score result final win", configure: { widget in
                         widget.options.match.home = "BRA"
                         widget.options.match.away = "ITA"
                         widget.options.match.homeColor = WidgetColor(hex: 0xFFD400)
                         widget.options.match.awayColor = WidgetColor(hex: 0x1F5FBF)
                         widget.options.match.homeScore = 4
                         widget.options.match.awayScore = 1
                         widget.options.match.competition = "FINAL · 1970"
                     }),
        CatalogEntry("goalCounter", .milestone, .football, title: "Goal Counter"),
        CatalogEntry("matchTicket", .ticket, .football, title: "Match Ticket", summary: "Your seat for the big game",
                     keywords: "match game stadium seat final", configure: { widget in
                         widget.options.ticket.headline = "CUP FINAL"
                         widget.options.ticket.subtitle = "Under the lights"
                         widget.options.ticket.venue = "National Stadium"
                         widget.options.ticket.seat = "BLOCK 7 · ROW 10"
                         widget.options.ticket.date = Calendar.current.date(byAdding: .day, value: 21, to: .now)
                         widget.tint = WidgetColor(hex: 0x0B5D3B)
                     }),
    ]

    static let mystic: [CatalogEntry] = [
        CatalogEntry("tarot", .tarot, .mystic, title: "Card of the Day"),
        CatalogEntry("aura", .aura, .mystic, title: "Today's Aura"),
        CatalogEntry("zodiac", .zodiac, .mystic),
        CatalogEntry("eightBall", .eightBall, .mystic),
        CatalogEntry("candle", .candle, .mystic),
        CatalogEntry("academiaCandle", .candle, .mystic, title: "Study Candle", summary: "A candle for late nights with old books",
                     keywords: "dark academia study library", configure: { widget in
                         widget.tint = WidgetColor(hex: 0x1A120C)
                         widget.options.customText = "one more chapter"
                     }),
    ]

    static let music: [CatalogEntry] = [
        CatalogEntry("cassette", .cassette, .music),
        CatalogEntry("vhs", .vhs, .music),
        CatalogEntry("visualizer", .visualizer, .music),
        CatalogEntry("ringVisualizer", .visualizer, .music, title: "Ring Visualizer", summary: "Bars circling the album art",
                     symbol: "circle.dotted", keywords: "ring circle album art", configure: { widget in
                         widget.options.visualizer = .ring
                         widget.tint = WidgetColor(hex: 0xB36BFF)
                     }),
        CatalogEntry("waveform", .visualizer, .music, title: "Waveform", summary: "A mirrored wave, like a voice note",
                     symbol: "waveform.path", keywords: "wave waveform mirror voice", configure: { widget in
                         widget.options.visualizer = .mirror
                         widget.tint = WidgetColor(hex: 0x4DD8FF)
                     }),
        CatalogEntry("concertTicket", .ticket, .music, title: "Concert Ticket", configure: { widget in
            widget.options.ticket.date = Calendar.current.date(byAdding: .day, value: 30, to: .now)
            widget.tint = WidgetColor(hex: 0xE0314B)
        }),
    ]
}
