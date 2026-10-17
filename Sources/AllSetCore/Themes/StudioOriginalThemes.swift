import Foundation

/// A separate, self-directed collection of complete desktop compositions.
/// It uses original bundled wallpaper art and distinct native art pieces.
public enum StudioOriginalThemes {
    public struct Design: Sendable {
        public let theme: WidgetTheme
        public let collections: [ThemeCollection]
        public let tags: String
        public let philosophy: String
        public let cardArt: ThemeCardArt.Picks
        public let lighting: ThemeAccent
        public let dark: Bool
    }

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.theme.id, $0) })
    public static func design(_ id: String) -> Design? { byID[id] }

    private static func wallpaper(_ name: String) -> WallpaperSource {
        .photo(.bundled("original-\(name).jpg"))
    }

    private static func photo(_ name: String, frame: PhotoFrame = .inset) -> Kit.Configure {
        { widget, _ in
            widget.options.images = [.bundled("original-\(name).jpg")]
            widget.options.photoFrame = frame
        }
    }

    private static func metric(_ value: SystemMetric) -> Kit.Configure {
        { widget, _ in widget.options.metric = value }
    }

    private static let shortcuts: Kit.Configure = { widget, theme in
        Kit.clear(&widget, theme)
        let symbols = ["photo.on.rectangle", "music.note", "pin", "note.text", "safari",
                       "envelope", "calendar", "play.rectangle", "folder"]
        widget.options.shortcuts = ShortcutItem.starters.enumerated().map { index, item in
            var item = item
            item.symbol = symbols[index]
            return item
        }
    }

    /// Five balanced grids. Each theme supplies its own art, copy, colors
    /// and widget styling; the open spaces are deliberate.
    private static func kit(_ layout: Int, phrase: String, image: String, themeID: String) -> [KitItem] {
        // The six commissioned wallpapers each get a bespoke composition.
        // The remaining layouts are temporary foundations until their artwork arrives.
        switch themeID {
        case "haloAtlas":
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.moon, .small, 2, 0),
                KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .medium, 0, 1, photo(image, frame: .fullBleed)),
                KitItem(.date, .small, 2, 1, Kit.bare),
                KitItem(.quote, .medium, 4, 1, Kit.words(phrase, style: .editorial)),
                KitItem(.metric, .medium, 0, 2, metric(.cpu)),
                KitItem(.nowPlaying, .medium, 4, 2),
                KitItem(.shortcuts, .medium, 0, 3, shortcuts),
                KitItem(.calendar, .medium, 4, 3),
            ]
        case "tideglass":
            return [
                KitItem(.weather, .medium, 0, 0),
                KitItem(.date, .small, 2, 0, Kit.bare),
                KitItem(.clock, .medium, 4, 0, Kit.bare),
                KitItem(.daylight, .small, 0, 1),
                KitItem(.photo, .large, 1, 1, photo(image, frame: .fullBleed)),
                KitItem(.quote, .medium, 4, 1, Kit.words(phrase, style: .elegant)),
                KitItem(.habits, .medium, 4, 2),
                KitItem(.todo, .medium, 0, 3, Kit.list("flow with the day")),
                KitItem(.nowPlaying, .medium, 2, 3),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
            ]
        case "duneStudy":
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.weather, .small, 3, 0),
                KitItem(.date, .small, 5, 0, Kit.bare),
                KitItem(.calendar, .large, 0, 1),
                KitItem(.todo, .medium, 2, 1, Kit.list("one thing at a time")),
                KitItem(.photo, .medium, 4, 1, photo(image)),
                KitItem(.goals, .medium, 2, 2),
                KitItem(.focus, .medium, 4, 2),
                KitItem(.quote, .medium, 0, 3, Kit.words(phrase, style: .typewriter)),
                KitItem(.shortcuts, .medium, 2, 3, shortcuts),
                KitItem(.nowPlaying, .medium, 4, 3),
            ]
        case "verdantAfterdark":
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.weather, .small, 2, 0),
                KitItem(.moon, .small, 5, 0),
                KitItem(.quote, .medium, 0, 1, Kit.words(phrase, style: .luxe)),
                KitItem(.photo, .large, 2, 1, photo(image, frame: .fullBleed)),
                KitItem(.candle, .small, 5, 1),
                KitItem(.habits, .medium, 0, 2),
                KitItem(.daylight, .small, 5, 2),
                KitItem(.nowPlaying, .medium, 0, 3),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
            ]
        case "prismWorkshop":
            return [
                KitItem(.date, .small, 0, 0, Kit.bare),
                KitItem(.clock, .medium, 1, 0, Kit.bare),
                KitItem(.weather, .medium, 4, 0),
                KitItem(.photo, .medium, 0, 1, photo(image, frame: .fullBleed)),
                KitItem(.goals, .medium, 2, 1),
                KitItem(.quote, .medium, 4, 1, Kit.words(phrase, style: .modern)),
                KitItem(.todo, .medium, 0, 2, Kit.list("make something bright")),
                KitItem(.focus, .medium, 2, 2),
                KitItem(.habits, .medium, 4, 2),
                KitItem(.shortcuts, .medium, 0, 3, shortcuts),
                KitItem(.nowPlaying, .medium, 4, 3),
            ]
        case "inkAndIvory":
            return [
                KitItem(.weather, .small, 0, 0),
                KitItem(.date, .small, 3, 0, Kit.bare),
                KitItem(.clock, .medium, 4, 0, Kit.bare),
                KitItem(.quote, .large, 0, 1, Kit.words(phrase, style: .editorial)),
                KitItem(.photo, .medium, 2, 1, photo(image)),
                KitItem(.calendar, .medium, 4, 1),
                KitItem(.note, .medium, 2, 2),
                KitItem(.daylight, .small, 5, 2),
                KitItem(.shortcuts, .medium, 0, 3, shortcuts),
                KitItem(.nowPlaying, .medium, 4, 3),
            ]
        default: break
        }
        switch layout {
        case 0:
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.date, .small, 2, 0, Kit.bare),
                KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .medium, 0, 1, photo(image, frame: .fullBleed)),
                KitItem(.moon, .small, 2, 1),
                KitItem(.quote, .medium, 4, 1, Kit.words(phrase, style: .editorial)),
                KitItem(.metric, .medium, 0, 2, metric(.cpu)),
                KitItem(.nowPlaying, .medium, 4, 2),
                KitItem(.shortcuts, .medium, 0, 3, shortcuts),
                KitItem(.calendar, .medium, 4, 3),
            ]
        case 1:
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.calendar, .small, 2, 0),
                KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .large, 0, 1, photo(image)),
                KitItem(.quote, .medium, 2, 1, Kit.words(phrase, style: .editorial)),
                KitItem(.todo, .medium, 4, 1, Kit.list("the small things")),
                KitItem(.habits, .medium, 2, 2),
                KitItem(.daylight, .small, 5, 2),
                KitItem(.nowPlaying, .medium, 2, 3),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
            ]
        case 2:
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.date, .small, 2, 0, Kit.bare),
                KitItem(.weather, .small, 5, 0),
                KitItem(.calendar, .large, 0, 1),
                KitItem(.todo, .medium, 2, 1, Kit.list("today, with purpose")),
                KitItem(.goals, .medium, 4, 1),
                KitItem(.photo, .medium, 2, 2, photo(image)),
                KitItem(.focus, .medium, 4, 2),
                KitItem(.nextEvent, .medium, 0, 3),
                KitItem(.shortcuts, .medium, 2, 3, shortcuts),
                KitItem(.nowPlaying, .medium, 4, 3),
            ]
        case 3:
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.weather, .small, 5, 0),
                KitItem(.quote, .large, 2, 1, Kit.words(phrase, style: .poster)),
                KitItem(.photo, .medium, 0, 1, photo(image)),
                KitItem(.candle, .small, 4, 1),
                KitItem(.moon, .small, 5, 1),
                KitItem(.nowPlaying, .medium, 0, 2),
                KitItem(.habits, .medium, 4, 2),
                KitItem(.sticker, .small, 0, 3),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
            ]
        default:
            return [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.battery, .small, 2, 0),
                KitItem(.weather, .medium, 4, 0),
                KitItem(.metric, .small, 0, 1, metric(.cpu)),
                KitItem(.metric, .small, 1, 1, metric(.memory)),
                KitItem(.photo, .small, 3, 1, photo(image)),
                KitItem(.calendar, .medium, 4, 1),
                KitItem(.terminal, .medium, 0, 2),
                KitItem(.focus, .medium, 4, 2),
                KitItem(.nowPlaying, .medium, 0, 3),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
            ]
        }
    }

    private static func make(
        _ id: String, _ title: String, _ tagline: String,
        wallpaper: WallpaperSource, image: String, card: Int, ink: Int, accent: Int,
        palette: ArtPalette, layout: Int, dark: Bool, font: WidgetFont = .serif,
        material: WidgetMaterial = .paper, style: TextStyle = .editorial,
        radius: Double = 16, mood: ThemeCollection, phrase: String, tags: String
    ) -> Design {
        let items = kit(layout, phrase: phrase, image: image, themeID: id)
        let theme = WidgetTheme(
            id: id, title: title, tagline: tagline, material: material,
            card: WidgetColor(hex: card), ink: WidgetColor(hex: ink), accent: WidgetColor(hex: accent),
            wallpaperInk: WidgetColor(hex: ink), wallpaperAccent: WidgetColor(hex: accent),
            font: font, cornerRadius: radius, textStyle: style, clockFace: .minimal,
            palette: palette, photoFilter: .none,
            noteColor: dark || id == "inkAndIvory" ? .blue : .green, sticker: .sparkles,
            stickerFinish: dark ? .chrome : .soft, stickerColor: WidgetColor(hex: accent),
            iconSymbol: "sparkles", wallpaper: wallpaper, photos: [],
            kit: items.map { item in
                KitItem(item.kind, item.size, item.column, item.row) { widget, theme in
                    item.configure(&widget, theme)
                    if widget.options.font == nil { widget.options.font = theme.font }
                    if widget.options.cornerRadius == nil { widget.options.cornerRadius = theme.cornerRadius }
                    if widget.material != .photo { widget.options.background = nil }
                    widget.options.animateArt = false
                    widget.options.neonFlicker = false
                }
            })
        let picks = ThemeCardArt.picks(from: items.map { ($0.kind, $0.size) })!
        return Design(
            theme: theme, collections: [.studioOriginals, mood],
            tags: tags, philosophy: "\(tagline) The composition pairs original artwork with useful, individually editable widgets.",
            cardArt: picks,
            lighting: ThemeAccent(primary: WidgetColor(hex: accent).lit,
                                  secondary: WidgetColor(hex: card).paled,
                                  glowIntensity: dark ? 0.82 : 0.6),
            dark: dark)
    }

    public static let all: [Design] = [
        make("haloAtlas", "Halo Atlas", "Blue orbital geometry reflected across a quiet horizon.",
             wallpaper: wallpaper("halo-atlas"), image: "halo-atlas", card: 0x101B2D, ink: 0xEAF4FF, accent: 0x66AFFF,
             palette: .ember, layout: 0, dark: true, font: .monospaced, material: .glass,
             mood: .cosmic, phrase: "Keep the long view.", tags: "orbit astronomy copper cosmic"),
        make("arcTheory", "Arc Theory", "A colossal blue world traced by precise orbital arcs.",
             wallpaper: wallpaper("arc-theory"), image: "arc-theory", card: 0x101B38, ink: 0xEDF2FF, accent: 0xA9BFFF,
             palette: .royal, layout: 4, dark: true, font: .monospaced, material: .glass,
             mood: .developer, phrase: "Trace the next idea.", tags: "orbital geometry precise blue"),
        make("staticStar", "Static Star", "A star-filled mountain basin for slow, luminous work.",
             wallpaper: wallpaper("static-star"), image: "static-star", card: 0x142039, ink: 0xF2F5FF, accent: 0xA8C7F0,
             palette: .midnight, layout: 1, dark: true, material: .glass,
             mood: .cosmic, phrase: "A little more wonder.", tags: "starfield night astronomy"),
        make("emberEclipse", "Ember Eclipse", "A copper eclipse burns above a misty volcanic horizon.",
             wallpaper: wallpaper("ember-eclipse"), image: "ember-eclipse", card: 0x291D18, ink: 0xFFF2E6, accent: 0xF2A76A,
             palette: .ember, layout: 3, dark: true, material: .frosted, style: .luxe,
             mood: .night, phrase: "THE NIGHT IS YOURS", tags: "eclipse ember smoke"),
        make("midnightMathematics", "Midnight Mathematics", "A measured dark grid with a sharp blue pulse.",
             wallpaper: .art(.init(style: .stripes, palette: .shadow)), image: "obsidian-orbit", card: 0x202834, ink: 0xE9F1F9, accent: 0x8EB9D9,
             palette: .shadow, layout: 2, dark: true, font: .monospaced, material: .glass,
             mood: .developer, phrase: "Make room to think.", tags: "grid dark work study"),
        make("tideglass", "Tideglass", "Pearlescent water and distant mountains in clear daylight.",
             wallpaper: wallpaper("tideglass"), image: "tideglass", card: 0xE9F8F5, ink: 0x24545A, accent: 0x3F999D,
             palette: .ocean, layout: 1, dark: false, material: .frosted, radius: 22,
             mood: .colourAndLight, phrase: "Move like water.", tags: "aqua glass wave light"),
        make("pearlCurrent", "Pearl Current", "A pearl-and-teal planner for an easy flow.",
             wallpaper: .art(.init(style: .waves, palette: .ocean)), image: "glass-tide", card: 0xF4FAF8, ink: 0x244B54, accent: 0x4097A5,
             palette: .ocean, layout: 2, dark: false, material: .paper,
             mood: .zen, phrase: "Find a softer rhythm.", tags: "wave planner teal pearl"),
        make("saltAir", "Salt Air", "Sky blue space and a few useful notes.",
             wallpaper: .art(.init(style: .clouds, palette: .sky)), image: "glass-tide", card: 0xF8FAFB, ink: 0x3D5C75, accent: 0x76A9CC,
             palette: .sky, layout: 0, dark: false, font: .rounded, radius: 24,
             mood: .dreamy, phrase: "Take the long way home.", tags: "sky breezy blue"),
        make("azureDaylight", "Azure Daylight", "A sunny blue desk with space to breathe.",
             wallpaper: .art(.init(style: .sunset, palette: .sky)), image: "glass-tide", card: 0xF7FAF4, ink: 0x3D5869, accent: 0x79AFC9,
             palette: .sky, layout: 3, dark: false, font: .rounded, style: .modern,
             mood: .colourAndLight, phrase: "MAKE TODAY LIGHT", tags: "daylight blue optimism"),
        make("deepLagoon", "Deep Lagoon", "A submerged blue workspace with glass instruments.",
             wallpaper: .art(.init(style: .waves, palette: .midnight)), image: "glass-tide", card: 0x162D3C, ink: 0xEAFAFF, accent: 0x6CC5D2,
             palette: .ocean, layout: 4, dark: true, font: .monospaced, material: .glass,
             mood: .night, phrase: "Stay in the flow.", tags: "lagoon underwater teal"),
        make("duneStudy", "Dune Study", "Terracotta ridges and warm, disciplined paper.",
             wallpaper: wallpaper("terracotta-dunes"), image: "terracotta-dunes", card: 0xF4E2D4, ink: 0x654133, accent: 0xBA6D4B,
             palette: .desert, layout: 2, dark: false, radius: 10,
             mood: .designer, phrase: "One thing at a time.", tags: "dunes desert study rust"),
        make("claybound", "Claybound", "Clay-colored pages under a wide-open sky.",
             wallpaper: .art(.init(style: .dunes, palette: .desert)), image: "terracotta-dunes", card: 0xF3E4D4, ink: 0x5C4135, accent: 0xAD7656,
             palette: .desert, layout: 1, dark: false, style: .handwritten,
             mood: .zen, phrase: "Rooted in the moment.", tags: "clay beige desert"),
        make("solsticeRoad", "Solstice Road", "A warm horizon for plans that can wait.",
             wallpaper: .art(.init(style: .sunset, palette: .peach)), image: "terracotta-dunes", card: 0xFFF0DF, ink: 0x794932, accent: 0xE98755,
             palette: .peach, layout: 0, dark: false, style: .elegant,
             mood: .colourAndLight, phrase: "Follow the warm light.", tags: "sunset peach route"),
        make("heatHaze", "Heat Haze", "An amber afterglow with soft glass controls.",
             wallpaper: .art(.init(style: .bokeh, palette: .sunset)), image: "terracotta-dunes", card: 0x3F2A25, ink: 0xFFF1DB, accent: 0xF8AF72,
             palette: .sunset, layout: 3, dark: true, material: .glass,
             mood: .ambient, phrase: "SLOW THE EVENING", tags: "amber heat haze sunset"),
        make("cinderField", "Cinder Field", "Blackened earth and a few bright sparks.",
             wallpaper: .art(.init(style: .embers, palette: .rage)), image: "terracotta-dunes", card: 0x29211E, ink: 0xFFEFE5, accent: 0xD88453,
             palette: .rage, layout: 4, dark: true, font: .monospaced, material: .glass,
             mood: .night, phrase: "Start a new fire.", tags: "cinder ember charcoal"),
        make("verdantAfterdark", "Verdant Afterdark", "Luminous leaves frame a midnight desk.",
             wallpaper: wallpaper("electric-garden"), image: "electric-garden", card: 0x122622, ink: 0xECFFF6, accent: 0x64D8AC,
             palette: .emerald, layout: 0, dark: true, material: .glass,
             mood: .night, phrase: "Grow after dark.", tags: "bioluminescent garden green night"),
        make("orchidSignal", "Orchid Signal", "Violet and green light for restless ideas.",
             wallpaper: .art(.init(style: .bokeh, palette: .emerald)), image: "electric-garden", card: 0x182B28, ink: 0xF1FFF9, accent: 0x90CEAA,
             palette: .emerald, layout: 4, dark: true, font: .monospaced, material: .glass,
             mood: .developer, phrase: "Follow the signal.", tags: "orchid botanical signal"),
        make("mossAndMercury", "Moss & Mercury", "Botanical green meets a little polished silver.",
             wallpaper: .art(.init(style: .waves, palette: .emerald)), image: "electric-garden", card: 0xEAF2E9, ink: 0x355246, accent: 0x6E9D82,
             palette: .matcha, layout: 2, dark: false, radius: 12,
             mood: .zen, phrase: "Let the day unfold.", tags: "moss sage green organic"),
        make("rainroom", "Rainroom", "A rainy green shelter for quiet work.",
             wallpaper: .art(.init(style: .rain, palette: .forest)), image: "electric-garden", card: 0x1F302B, ink: 0xF0F7ED, accent: 0x9EC4A5,
             palette: .forest, layout: 1, dark: true, material: .frosted,
             mood: .indie, phrase: "Stay a little longer.", tags: "rain forest green cozy"),
        make("nightHerbarium", "Night Herbarium", "A dark botanical archive with delicate stars.",
             wallpaper: .art(.init(style: .stars, palette: .forest)), image: "electric-garden", card: 0x1D2B22, ink: 0xF2F4E8, accent: 0xA4BF82,
             palette: .forest, layout: 3, dark: true, material: .glass, style: .elegant,
             mood: .dreamy, phrase: "TEND TO WONDER", tags: "herbarium botany starlight"),
        make("prismWorkshop", "Prism Workshop", "An ivory studio crossed by soft spectral light.",
             wallpaper: wallpaper("prism-atelier"), image: "prism-atelier", card: 0xF8F5FB, ink: 0x4B4A65, accent: 0x9E83C0,
             palette: .pastel, layout: 2, dark: false, radius: 12,
             mood: .designer, phrase: "Ideas in every color.", tags: "prism rainbow acrylic workshop"),
        make("chromaticPause", "Chromatic Pause", "Playful geometry with a considered pastel palette.",
             wallpaper: .art(.init(style: .checker, palette: .pastel)), image: "prism-atelier", card: 0xF8F0F8, ink: 0x504862, accent: 0xAE7BAE,
             palette: .pastel, layout: 1, dark: false, font: .rounded, radius: 24,
             mood: .pop, phrase: "A brighter interval.", tags: "chromatic pastel checker"),
        make("inkAndIvory", "Ink & Ivory", "An indigo gesture on an open gallery wall.",
             wallpaper: wallpaper("ink-bloom"), image: "ink-bloom", card: 0xF6F5F1, ink: 0x263D5B, accent: 0x365E91,
             palette: .sky, layout: 0, dark: false, radius: 8,
             mood: .minimal, phrase: "Leave a little space.", tags: "indigo ink ivory gallery"),
        make("blueMargins", "Blue Margins", "A blue-ink planner for thoughts still forming.",
             wallpaper: .art(.init(style: .blobs, palette: .sky)), image: "ink-bloom", card: 0xF4F8FC, ink: 0x344C71, accent: 0x6A8DC3,
             palette: .sky, layout: 2, dark: false, style: .typewriter, radius: 10,
             mood: .designer, phrase: "Write the next line.", tags: "blue margins writing notes"),
        make("afterimage", "Afterimage", "Electric color trails across a deep black field.",
             wallpaper: .art(.init(style: .spiral, palette: .neon)), image: "prism-atelier", card: 0x1C1934, ink: 0xF8F0FF, accent: 0xD99BFF,
             palette: .neon, layout: 3, dark: true, font: .condensed, material: .glass, style: .poster,
             mood: .neon, phrase: "KEEP MOVING", tags: "afterimage neon motion electric"),
    ]
}
