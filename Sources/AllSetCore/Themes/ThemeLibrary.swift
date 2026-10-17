import Foundation

/// Every theme set in the library, and the ways to find them.
public enum ThemeLibrary {
    public static let all: [ThemeSet] = setups

    public static func set(_ id: String) -> ThemeSet? {
        let id = LegacyIdentifiers.theme(id)
        return all.first { $0.id == id }
    }

    public static func sets(in collection: ThemeCollection) -> [ThemeSet] {
        all.filter { $0.collections.contains(collection) }
    }

    /// Sets whose words hold every word typed ("night", "pink", "developer").
    public static func search(_ query: String) -> [ThemeSet] {
        let ranked = SearchMatch.rank(all, by: query, name: \.name)
        let rankedIDs = Set(ranked.map(\.id))
        return ranked + all.filter { !rankedIDs.contains($0.id) && SearchMatch.containsAll(query, in: $0.searchText) }
    }

    // MARK: Setups

    /// Every setup as a set: the photo-led moodboards first, then the rest.
    static let setups: [ThemeSet] = WidgetTheme.all.enumerated().map { index, theme in
        let reference = ReferenceThemes.design(theme.id)
        let original = StudioOriginalThemes.design(theme.id)
        let newEdit = DatasetTwoThemes.design(theme.id)
        let supplied = FunkyThemes.design(theme.id)
        let isMoodboard = index < WidgetTheme.moodboards.count
        let (collections, tags): ([ThemeCollection], String) = switch theme.id {
        case "midnightAurora": ([.featured, .night, .dreamy, .cinematic, .ambient], "aurora northern lights fjord blue violet glass calm nature")
        case "leopardNoir": ([.featured, .artistWorlds, .luxury, .night], "leopard diva hollywood glam black white photos script")
        case "cityNoir": ([.featured, .artistWorlds, .night, .minimal], "city skyline night black white noir")
        case "angelic": ([.featured, .artistWorlds, .luxury], "angel lace white script monogram")
        case "hypnotic": ([.featured, .artistWorlds, .night, .indie], "spiral flip clock film stills monochrome")
        case "afterDark": ([.featured, .artistWorlds, .night, .hipHop, .rock], "swag grunge gothic collage dark")
        case "streetwear": ([.artistWorlds, .hipHop, .designer], "streetwear topographic contour bold white")
        case "gallery": ([.artistWorlds, .designer, .minimal], "architecture zine concrete vinyl monochrome")
        case "silverFaith": ([.artistWorlds, .night, .luxury], "chrome silver black faith gothic")
        case "peaceOfMind": ([.artistWorlds, .night, .ambient], "bismillah script peace night")
        case "cherryNight": ([.artistWorlds, .night, .rnb], "cherry red floral petals romance")
        case "stardust": ([.artistWorlds, .night, .cosmic, .dreamy], "stars sparkle wings burst black white")
        case "softMono": ([.artistWorlds, .minimal, .designer], "light gray minimal handwriting mono")
        case "bohoSand": ([.artistWorlds, .minimal, .zen], "boho beige sand cream flowers")
        case "beginning": ([.artistWorlds, .designer, .developer], "ink fluid orange dashboard")
        case "floodlightGold": ([.featured, .football], "football soccer floodlight captain red green gold stadium")
        case "rainDerby": ([.featured, .football], "football soccer winger rain derby red young step-overs")
        case "wonderkid": ([.football, .pop], "football soccer young wonderkid prodigy violet gold bokeh")
        case "midnightSprint": ([.football, .night], "football soccer sprint speed navy gold city night")
        case "emberTerrace": ([.football, .retro], "football soccer terrace ember flares red charcoal elegance")
        case "legends": ([.football, .luxury], "football soccer legends greatest all time hall of fame")
        case "ivoryCrown": ([.football, .luxury], "football soccer ivory crown white gold trophies cup night")
        case "skyPlaymaker": ([.featured, .football], "football soccer playmaker sky white magic assists")
        case "goldenAge": ([.football, .retro], "football soccer golden age retro yellow film old school")
        case "neonFlair": ([.football, .neon], "football soccer street flair skill neon yellow")
        case "palmNightPink": ([.football, .night], "football soccer pink black palms seaside")
        case "matchday": ([.football, .night], "football soccer match stadium floodlights tactics ticket derby")
        case "americana": ([.featured, .musicIcons, .cinematic], "americana hollywood vintage cherry palms vhs summer")
        case "coastline": ([.musicIcons, .dreamy], "coastal california ocean pastel polaroid cassette")
        case "violetNoir": ([.musicIcons, .night, .luxury], "noir black white roses jazz velvet torch song")
        case "emberCrowd": ([.musicIcons, .hipHop], "mosh smoke fire ember crowd brown orange concert loud")
        case "rainHours": ([.musicIcons, .night], "sad blue rain emo night 3am")
        case "acidMoss": ([.featured, .musicIcons, .night], "acid moss green black alt neon weird")
        case "deepBlue": ([.musicIcons, .ambient], "ocean deep blue underwater soft")
        case "crimsonNights": ([.musicIcons, .rnb, .neon], "red neon city night drive late show")
        case "gothicStatic": ([.musicIcons, .rock, .hipHop], "gothic static punk blackletter red black")
        case "sunflowerDrive": ([.musicIcons, .indie], "sunflower drive summer orange cream sunflowers")
        case "matchaMorning": ([.colourAndLight, .dreamy, .zen], "matcha green sage oat light morning calm cozy handwriting")
        case "peachFizz": ([.colourAndLight, .pop], "peach coral orange light summer sunshine happy bright")
        case "lavenderHaze": ([.colourAndLight, .dreamy, .ambient], "lavender lilac purple pastel light clouds soft dreamy")
        case "candyPop": ([.colourAndLight, .pop, .retro], "candy bubblegum pink checkerboard y2k colorful playful light glitter")
        case "oceanGlass": ([.colourAndLight, .ambient, .night], "ocean sea blue aqua waves glass calm")
        case "sunsetDrive": ([.colourAndLight, .retro, .neon, .night], "sunset synthwave orange pink drive retro 80s cassette vinyl")
        case "forestCabin": ([.colourAndLight, .indie, .zen], "forest pine green rain cabin cozy woods autumn typewriter")
        case "desertBloom": ([.colourAndLight, .indie, .minimal], "desert sand terracotta boho warm dunes flowers")
        case "cloudNine", "pinkLatte", "coquette": ([.dreamy, .pop], "")
        case "goodThings", "grunge": ([.minimal, .night, .rock], "")
        case "diva", "luxeNoir": ([.luxury, .night], "")
        case "sepia": ([.retro, .hipHop], "")
        case "vigilante": ([.night, .cinematic, .neon], "")
        case "neonNights": ([.neon, .night, .developer], "")
        case "darkAcademia": ([.indie, .night], "")
        case "midnightLofi": ([.ambient, .night, .indie], "")
        case "goth": ([.night, .rock], "")
        default: ([.designer], "")
        }
        let fanIndex = WidgetTheme.fandom.firstIndex { $0.id == theme.id }
        let isColour = WidgetTheme.colour.contains { $0.id == theme.id }
        let philosophy = fanIndex == nil
            ? "A desktop setup in the style people share: photos, words, cards and a wallpaper that go together."
            : "Original artwork and free-to-use photos in the mood of an era fans know: no official photos, logos or lyrics. Add your own photos to make it yours."
        return ThemeSet(id: "setup.\(theme.id)", name: theme.title, tagline: theme.tagline,
                        description: "\(theme.tagline) A whole desktop, with its own wallpaper and layout.",
                        philosophy: supplied?.philosophy ?? newEdit?.philosophy ?? original?.philosophy ?? reference?.philosophy ?? philosophy, inspiration: inspirations[theme.id],
                        collections: supplied?.collections ?? newEdit?.collections ?? original?.collections ?? reference?.collections ?? collections,
                        tags: "\(theme.id) \(supplied?.tags ?? newEdit?.tags ?? original?.tags ?? reference?.tags ?? tags)", look: .setup(theme.id), layout: [],
                        added: supplied != nil ? "2026-10-18" : newEdit != nil || original != nil || reference != nil ? "2026-10-08" : theme.id == "midnightAurora" ? "2026-10-05" : isColour ? "2026-09-30" : isMoodboard || fanIndex != nil ? "2026-09-25" : "2026-09-24",
                        baseline: supplied != nil ? 98 : newEdit != nil ? 97 : original != nil ? 96 : reference != nil ? 94 : theme.id == "midnightAurora" ? 98 : isMoodboard ? 90 - Double(index) : fanIndex.map { spotlight[theme.id] ?? 88 - Double($0) } ?? (isColour ? 70 : 55),
                        accent: supplied?.lighting ?? newEdit?.lighting ?? original?.lighting ?? reference?.lighting ?? accents[theme.id])
    }
}

extension ThemeLibrary {
    /// The worlds that lead the library.
    static let spotlight: [String: Double] = ["floodlightGold": 97, "rainDerby": 96.5, "americana": 96, "skyPlaymaker": 93, "acidMoss": 92]

    /// The light each leading theme casts in the Themes hero: a neon color
    /// for its edge and glow, and a second for haze. Where a theme isn't
    /// listed, `ThemeSet.lighting` works one out from its look.
    static let accents: [String: ThemeAccent] = [
        "midnightAurora": ThemeAccent(0x41BFFF, 0xA374FF, glow: 0.9),
        // Neon crimson under warm gold floodlights.
        "floodlightGold": ThemeAccent(0xFF2D4A, 0xFFB347),
        "rainDerby": ThemeAccent(0xFF3B30, 0xFFD166),
        // Magenta dusk over a sunset orange.
        "americana": ThemeAccent(0xFF5E8A, 0xFF9A3C, glow: 0.85),
        // Electric sky and white.
        "skyPlaymaker": ThemeAccent(0x4CC3FF, 0xFFFFFF, glow: 0.9),
        "acidMoss": ThemeAccent(0x7CFF3A, 0x1FD98A, glow: 0.8),
        // Bright themes glow less: their own pictures carry the light.
        "peachFizz": ThemeAccent(0xFF9E7A, 0xFFD0B0, glow: 0.65),
        "matchaMorning": ThemeAccent(0xA8C686, 0xE8E2C8, glow: 0.6),
        // Black-and-white themes get a deliberate color, never gray: old
        // gold, icy silver-blue, moonlight with streetlamp amber, violet
        // haze, bone gold.
        "leopardNoir": ThemeAccent(0xD9A441, 0x8A6A3A, glow: 0.8),
        "angelic": ThemeAccent(0xCFE3FF, 0xFFFFFF, glow: 0.7),
        "cityNoir": ThemeAccent(0x9FBBEA, 0xF2B66D, glow: 0.85),
        "hypnotic": ThemeAccent(0xB9A2F5, 0xFFFFFF, glow: 0.85),
        "afterDark": ThemeAccent(0xE3CF9A, 0x8A7A5A, glow: 0.8),
    ]

    /// What each football and music world draws on: moods, never people, clubs or nations.
    static let inspirations: [String: String] = [
        "floodlightGold": "Inspired by floodlit cup nights",
        "rainDerby": "Inspired by a winger's rainy derby",
        "wonderkid": "Inspired by a teenage prodigy's first season",
        "midnightSprint": "Inspired by a counter-attack at midnight",
        "emberTerrace": "Inspired by flares on an old terrace",
        "legends": "Inspired by the all-time greats of the game",
        "ivoryCrown": "Inspired by grand cup nights in ivory and gold",
        "skyPlaymaker": "Inspired by a playmaker's touch",
        "goldenAge": "Inspired by old-school football on film",
        "neonFlair": "Inspired by street football and flair",
        "palmNightPink": "Inspired by pink-and-black nights by the sea",
        "matchday": "Inspired by floodlit Saturdays everywhere",
        "americana": "Inspired by cinematic Americana",
        "coastline": "Inspired by coastal road trips",
        "violetNoir": "Inspired by noir torch songs and old Hollywood",
        "emberCrowd": "Inspired by loud live shows",
        "rainHours": "Inspired by late-night blues",
        "acidMoss": "Inspired by quiet, glowing alt-pop",
        "deepBlue": "Inspired by the ocean at night",
        "crimsonNights": "Inspired by red-neon synth nights",
        "gothicStatic": "Inspired by gothic punk",
        "sunflowerDrive": "Inspired by sun-bleached summer drives",
    ]
}
