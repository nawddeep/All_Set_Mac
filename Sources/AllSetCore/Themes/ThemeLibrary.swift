import Foundation

/// Every theme set in the library, and the ways to find them.
public enum ThemeLibrary {
    public static let all: [ThemeSet] = setups

    public static func set(_ id: String) -> ThemeSet? { all.first { $0.id == id } }

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
        case "seven": ([.featured, .football], "football soccer ronaldo cristiano cr7 portugal seven 7 red green gold stadium goat")
        case "redSeven": ([.featured, .football], "football soccer ronaldo cristiano manchester united red devils seven 7 young")
        case "wonderkid": ([.football, .pop], "football soccer lamine yamal barcelona barca 19 young wonderkid")
        case "bleuRoyal": ([.football, .night], "football soccer mbappe kylian france paris bleus ten 10 speed")
        case "milanoNights": ([.football, .retro], "football soccer kaka maldini ac milan rossoneri red black stripes")
        case "legends": ([.football, .luxury], "football soccer legends greatest all time pele maradona zidane hall of fame")
        case "galactico": ([.football, .luxury], "football soccer ronaldo cristiano madrid white gold royal champions")
        case "albiceleste": ([.featured, .football], "football soccer messi argentina ten 10 sky blue stripes goat")
        case "oRei": ([.football, .retro], "football soccer pele brazil 1970 king retro yellow green")
        case "sambaNeon": ([.football, .neon], "football soccer neymar brazil samba flair skill neon yellow")
        case "miamiPink": ([.football, .night], "football soccer messi miami pink black palms")
        case "matchday": ([.football, .night], "football soccer match stadium floodlights tactics ticket derby")
        case "americana": ([.featured, .musicIcons, .cinematic], "lana del rey americana hollywood vintage cherry palms vhs sad girl summer")
        case "coastline": ([.musicIcons, .dreamy], "lana del rey coastal california ocean pastel polaroid cassette")
        case "violetNoir": ([.musicIcons, .night, .luxury], "lana del rey noir black white roses jazz ultraviolence velvet")
        case "rageMode": ([.musicIcons, .hipHop], "travis scott rage mosh smoke fire brown orange concert")
        case "sadHours": ([.musicIcons, .night], "xxxtentacion sad blue rain emo night 3am")
        case "slimeGreen": ([.featured, .musicIcons, .night], "billie eilish slime green black alt neon")
        case "deepBlue": ([.musicIcons, .ambient], "billie eilish ocean deep blue underwater soft")
        case "crimsonNights": ([.musicIcons, .rnb, .neon], "the weeknd after hours red neon vegas night drive")
        case "opiumPunk": ([.musicIcons, .rock, .hipHop], "playboi carti vamp punk gothic red black opium")
        case "blondSummer": ([.musicIcons, .indie], "frank ocean blond summer orange cream sunflowers")
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
                        philosophy: philosophy, inspiration: inspirations[theme.id],
                        collections: collections, tags: "\(theme.id) \(tags)", look: .setup(theme.id), layout: [],
                        added: theme.id == "midnightAurora" ? "2026-10-05" : isColour ? "2026-09-30" : isMoodboard || fanIndex != nil ? "2026-09-25" : "2026-09-24",
                        baseline: theme.id == "midnightAurora" ? 98 : isMoodboard ? 90 - Double(index) : fanIndex.map { spotlight[theme.id] ?? 88 - Double($0) } ?? (isColour ? 70 : 55),
                        accent: accents[theme.id])
    }
}

extension ThemeLibrary {
    /// The worlds that lead the library.
    static let spotlight: [String: Double] = ["seven": 97, "redSeven": 96.5, "americana": 96, "albiceleste": 93, "slimeGreen": 92]

    /// The light each leading theme casts in the Themes hero: a neon color
    /// for its edge and glow, and a second for haze. Where a theme isn't
    /// listed, `ThemeSet.lighting` works one out from its look.
    static let accents: [String: ThemeAccent] = [
        "midnightAurora": ThemeAccent(0x41BFFF, 0xA374FF, glow: 0.9),
        // Neon crimson under warm gold floodlights.
        "seven": ThemeAccent(0xFF2D4A, 0xFFB347),
        "redSeven": ThemeAccent(0xFF3B30, 0xFFD166),
        // Magenta dusk over a sunset orange.
        "americana": ThemeAccent(0xFF5E8A, 0xFF9A3C, glow: 0.85),
        // Electric sky and white.
        "albiceleste": ThemeAccent(0x4CC3FF, 0xFFFFFF, glow: 0.9),
        "slimeGreen": ThemeAccent(0x7CFF3A, 0x1FD98A, glow: 0.8),
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

    /// What each football and music world draws on, described without names.
    static let inspirations: [String: String] = [
        "seven": "Inspired by Portugal's legendary number seven",
        "redSeven": "Inspired by the young number seven's red-shirt years",
        "wonderkid": "Inspired by a teenage prodigy in claret and blue",
        "bleuRoyal": "Inspired by France's lightning-fast number ten",
        "milanoNights": "Inspired by the red-and-black Milan nights of the 2000s",
        "legends": "Inspired by the all-time greats of the game",
        "galactico": "Inspired by the white-and-gold galáctico era",
        "albiceleste": "Inspired by Argentina's number ten",
        "oRei": "Inspired by Brazil's king of 1970",
        "sambaNeon": "Inspired by Brazilian flair and street football",
        "miamiPink": "Inspired by pink-and-black nights in Miami",
        "matchday": "Inspired by floodlit Saturdays everywhere",
        "americana": "Inspired by cinematic Americana and sad-girl pop",
        "coastline": "Inspired by California-coast songwriting",
        "violetNoir": "Inspired by noir torch songs and old Hollywood",
        "rageMode": "Inspired by rage-era hip-hop shows",
        "sadHours": "Inspired by emo rap and late-night blues",
        "slimeGreen": "Inspired by whispery alt-pop in black and green",
        "deepBlue": "Inspired by oceanic, soft-then-loud alt-pop",
        "crimsonNights": "Inspired by red-neon synth R&B",
        "opiumPunk": "Inspired by gothic punk-rap",
        "blondSummer": "Inspired by sun-bleached, orange-hued R&B",
    ]
}
