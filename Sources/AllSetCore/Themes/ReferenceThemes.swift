import Foundation

/// Original desktop compositions drawn from the local reference study.
/// Metadata and kits stay together so discovery, installation and the widget
/// gallery all describe the same editable composition.
public enum ReferenceThemes {
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

    private static func make(
        _ id: String, _ name: String, _ tagline: String,
        wallpaper: WallpaperSource, card: Int, ink: Int, accent: Int,
        palette: ArtPalette, font: WidgetFont = .serif, style: TextStyle = .editorial,
        clock: ClockFace = .minimal, material: WidgetMaterial = .paper, radius: Double = 18,
        filter: PhotoFilter = .none, dark: Bool = false, sticker: StickerShape = .star,
        collections: [ThemeCollection], tags: String, philosophy: String,
        hero: Int, title: Int? = nil, flankers: [Int], kit: [KitItem]
    ) -> Design {
        let theme = WidgetTheme(
            id: id, title: name, tagline: tagline, material: material,
            card: WidgetColor(hex: card), ink: WidgetColor(hex: ink), accent: WidgetColor(hex: accent),
            wallpaperInk: WidgetColor(hex: ink), wallpaperAccent: WidgetColor(hex: accent),
            font: font, cornerRadius: radius, textStyle: style, clockFace: clock,
            palette: palette, photoFilter: filter,
            noteColor: dark ? .blue : (palette == .matcha ? .green : .pink),
            sticker: sticker, stickerFinish: dark ? .chrome : .outline,
            stickerColor: WidgetColor(hex: accent), iconSymbol: "sparkles",
            wallpaper: wallpaper, photos: [],
            kit: kit.map { item in
                KitItem(item.kind, item.size, item.column, item.row) { widget, theme in
                    item.configure(&widget, theme)
                    if widget.options.font == nil { widget.options.font = theme.font }
                    if widget.options.cornerRadius == nil { widget.options.cornerRadius = theme.cornerRadius }
                    // Default clocks have a remote photo that these cards do
                    // not use. Clear it so gallery preloading stays offline.
                    if widget.material != .photo { widget.options.background = nil }
                    // Decorative art is still in previews and quiet on the desktop.
                    widget.options.animateArt = false
                    widget.options.neonFlicker = false
                }
            })
        return Design(theme: theme, collections: [.desktopEdit] + collections,
                      tags: tags, philosophy: philosophy,
                      cardArt: .init(hero: hero, title: title, flankers: flankers),
                      lighting: ThemeAccent(primary: WidgetColor(hex: accent).lit,
                                            secondary: WidgetColor(hex: card).paled,
                                            glowIntensity: dark ? 0.8 : 0.6), dark: dark)
    }

    private static func wall(_ name: String) -> WallpaperSource { .photo(.bundled("edit-\(name).jpg")) }

    private static func picture(_ name: String, frame: PhotoFrame = .inset, caption: String = "") -> Kit.Configure {
        { widget, _ in
            widget.options.images = [.bundled(name.hasPrefix("cinema-") ? "\(name).jpg" : "edit-\(name).jpg")]
            widget.options.photoFrame = frame
            widget.options.caption = caption
        }
    }

    private static func prints(_ names: [String]) -> Kit.Configure {
        { widget, _ in widget.options.images = names.map { .bundled("edit-\($0).jpg") } }
    }

    private static func ornament(_ shape: CharmShape) -> Kit.Configure {
        { widget, theme in widget.options.charm = shape; widget.tint = theme.accent }
    }

    private static func clock(_ face: ClockFace, bare: Bool = false) -> Kit.Configure {
        { widget, theme in
            widget.options.clockFace = face
            if bare { Kit.clear(&widget, theme) }
        }
    }

    private static func metric(_ value: SystemMetric, bare: Bool = true) -> Kit.Configure {
        { widget, theme in
            widget.options.metric = value
            if bare { Kit.clear(&widget, theme) }
        }
    }

    private static let shortcuts: Kit.Configure = { widget, theme in
        Kit.clear(&widget, theme)
        // Keep the apps' individual symbols rather than replacing every icon.
        let symbols = ["photo.on.rectangle", "music.note", "pin", "note.text", "safari", "envelope", "calendar", "play.rectangle", "folder"]
        widget.options.shortcuts = ShortcutItem.starters.enumerated().map { index, item in
            var item = item
            item.symbol = symbols[index]
            return item
        }
    }

    private static let panelShortcuts: Kit.Configure = { widget, theme in
        shortcuts(&widget, theme)
        widget.material = theme.material
        widget.tint = theme.card
        widget.options.ink = theme.ink
        widget.options.accent = theme.accent
    }

    public static let all: [Design] = [
        make("ribbonRoom", "Ribbon Room", "Pink satin bows, lilac paper and a little room to dream.",
             wallpaper: wall("ribbon-room"), card: 0xF7EAF1, ink: 0x674653, accent: 0xB56D8A, palette: .coquette,
             style: .script, sticker: .heart, collections: [.featured, .dreamy, .colourAndLight],
             tags: "coquette ribbon bows lilac pink satin scrapbook",
             philosophy: "Two small edge clusters leave the ribbons visible. Rose still lifes, a bow charm and soft utility cards share dusty-pink ink.",
             hero: 3, title: 6, flankers: [1, 2, 5, 4], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.weather, .small, 2, 0),
                KitItem(.calendar, .small, 5, 0), KitItem(.photo, .medium, 0, 1, picture("rose-still-life")),
                KitItem(.todo, .medium, 4, 1, Kit.list("little plans")), KitItem(.charm, .small, 0, 2, ornament(.bow)),
                KitItem(.wordArt, .medium, 1, 2, Kit.wordArt("daydream", .gold, style: .script)),
                KitItem(.nowPlaying, .medium, 4, 3), KitItem(.shortcuts, .medium, 0, 3, shortcuts),
             ]),
        make("rosewater", "Rosewater", "A sculpted pink heart, quiet corners and gentle daily rituals.",
             wallpaper: wall("rose-heart"), card: 0xF8E7EA, ink: 0x764650, accent: 0xB85B79, palette: .blush,
             style: .elegant, radius: 24, sticker: .heart, collections: [.featured, .dreamy, .minimal],
             tags: "pink heart romantic minimal affirmation airy",
             philosophy: "The heart is the focal point. Only the corners carry weather, a calendar, reminders and a short affirmation.",
             hero: 0, flankers: [1, 2, 4, 5], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.weather, .small, 2, 0),
                KitItem(.calendar, .small, 5, 0), KitItem(.todo, .medium, 0, 1, Kit.list("one lovely thing")),
                KitItem(.charm, .small, 5, 1, ornament(.heart)),
                KitItem(.quote, .small, 0, 3, Kit.words("soft starts", style: .script, bare: true)),
                KitItem(.nowPlaying, .medium, 4, 3),
             ]),
        make("pearlLace", "Pearl Lace", "Ivory lace, pearl light and small handwritten moments.",
             wallpaper: wall("pearl-lace"), card: 0xFAF7EF, ink: 0x534940, accent: 0x9F7A4A, palette: .mocha,
             style: .script, radius: 12, collections: [.luxury, .minimal, .dreamy], tags: "lace cream pearl ivory tactile handwritten",
             philosophy: "Warm ivory fabric surrounds a loose upper-left photo cluster. A gold star and script phrase add detail without covering the textile.",
             hero: 2, title: 4, flankers: [1, 3, 5, 6], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 2, 0),
                KitItem(.polaroids, .large, 0, 1, prints(["rose-still-life", "botanical-paper", "analog-studio"])),
                KitItem(.sticker, .small, 2, 1), KitItem(.wordArt, .medium, 3, 1, Kit.wordArt("cherish", .gold, style: .script)),
                KitItem(.weather, .small, 5, 0), KitItem(.charm, .small, 5, 2, ornament(.star)),
                KitItem(.vinyl, .medium, 4, 3), KitItem(.shortcuts, .medium, 0, 3, shortcuts),
             ]),
        make("butterflyHour", "Butterfly Hour", "Dusty-rose time, ivory picture frames and floating wings.",
             wallpaper: wall("butterfly-blush"), card: 0xFFFAF7, ink: 0x795463, accent: 0xB76787, palette: .blush,
             clock: .analog, radius: 16, collections: [.dreamy, .colourAndLight], tags: "butterfly pink wings white photo frames",
             philosophy: "White inset photographs balance both edges of an open butterfly wallpaper. A rose analog face anchors the left group.",
             hero: 3, flankers: [0, 1, 2, 6], kit: [
                KitItem(.clock, .small, 0, 0), KitItem(.calendar, .small, 1, 0),
                KitItem(.weather, .small, 5, 0), KitItem(.photo, .large, 0, 1, picture("rose-still-life")),
                KitItem(.photo, .medium, 4, 1, picture("botanical-paper")), KitItem(.todo, .medium, 4, 2, Kit.list("take flight")),
                KitItem(.charm, .small, 2, 3, ornament(.butterfly)), KitItem(.nowPlaying, .medium, 0, 3),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("petalDiary", "Petal Diary", "A rose-tinted scrapbook of photos, records and everyday notes.",
             wallpaper: wall("ribbon-room"), card: 0xFFF4ED, ink: 0x704C55, accent: 0xB57588, palette: .coquette,
             font: .rounded, style: .handwritten, clock: .stacked, radius: 22, collections: [.dreamy, .pop], tags: "scrapbook blush diary photos music collage",
             philosophy: "A fuller scrapbook composition mixes prints, a broad floral photograph, a record and useful cards. Blush and cream keep the density calm.",
             hero: 0, title: 5, flankers: [1, 2, 4, 7], kit: [
                KitItem(.polaroids, .large, 0, 0, prints(["rose-still-life", "botanical-paper", "butterfly-blush"])),
                KitItem(.clock, .small, 2, 0), KitItem(.calendar, .small, 3, 0),
                KitItem(.photo, .medium, 4, 0, picture("rose-still-life", frame: .polaroid, caption: "petal notes")),
                KitItem(.vinyl, .small, 2, 1), KitItem(.wordArt, .medium, 3, 1, Kit.wordArt("dear diary", .gold, style: .script)),
                KitItem(.todo, .medium, 0, 2, Kit.list("today's pages")), KitItem(.weather, .small, 2, 2),
                KitItem(.photo, .medium, 3, 2, picture("botanical-paper")), KitItem(.charm, .small, 5, 2, ornament(.bow)),
                KitItem(.nowPlaying, .medium, 0, 3), KitItem(.habits, .medium, 2, 3),
             ]),
        make("cloudPost", "Cloud Post", "Baby-blue skies, round lilac cards and playful little keepsakes.",
             wallpaper: .art(.init(style: .clouds, palette: .sky)), card: 0xEEEAFE, ink: 0x4D4873, accent: 0x8170B8, palette: .pastel,
             font: .rounded, style: .chunky, radius: 28, sticker: .cloud, collections: [.pop, .dreamy, .colourAndLight], tags: "kawaii pastel sky lilac blue cloud playful",
             philosophy: "Round lilac cards sit beneath a generous blue sky. A teddy, cloud ornament and soft photograph give the functional corner clusters a playful rhythm.",
             hero: 3, flankers: [1, 2, 5, 6], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 2, 0), KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .large, 0, 1, picture("cinema-alpine")), KitItem(.todo, .medium, 4, 1, Kit.list("tiny adventures")),
                KitItem(.sticker, .small, 2, 2), KitItem(.sticker, .small, 5, 2, { w, _ in w.options.sticker = .teddy }),
                KitItem(.quote, .medium, 0, 3, Kit.words("a little brighter", style: .chunky, bare: true)), KitItem(.nowPlaying, .medium, 4, 3),
             ]),
        make("ivoryAgenda", "Ivory Agenda", "An orderly paper desk for plans, photos and your next small win.",
             wallpaper: wall("ivory-paper"), card: 0xF7F3EA, ink: 0x51483E, accent: 0x8C7357, palette: .mocha,
             radius: 10, collections: [.featured, .minimal, .designer], tags: "organizer agenda cream paper calendar tasks productivity",
             philosophy: "A calendar and two named checklists form clear working zones. A row of editorial photographs and fine serif words keeps the organizer personal.",
             hero: 3, flankers: [1, 6, 7, 8], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.date, .small, 2, 0, Kit.bare),
                KitItem(.quote, .medium, 4, 0, Kit.words("a considered day", style: .editorial, bare: true)),
                KitItem(.calendar, .large, 0, 1), KitItem(.todo, .medium, 2, 1, Kit.list("work & study")),
                KitItem(.todo, .medium, 4, 1, Kit.list("life & little things")),
                KitItem(.photo, .small, 2, 2, picture("botanical-paper")), KitItem(.photo, .small, 3, 2, picture("rose-still-life")),
                KitItem(.photo, .small, 4, 2, picture("analog-studio")), KitItem(.nextEvent, .medium, 0, 3),
                KitItem(.focus, .medium, 2, 3), KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("linenWeek", "Linen Week", "Oat paper, brown ink and a practical rhythm for the week.",
             wallpaper: wall("botanical-paper"), card: 0xEEE7DA, ink: 0x574939, accent: 0x997047, palette: .mocha,
             radius: 8, collections: [.minimal, .designer], tags: "beige linen weekly planner organizer brown calendar habits",
             philosophy: "The week belongs to a spacious calendar, upcoming events and habits. Warm paper cards stay on the left, leaving the botanical subject visible.",
             hero: 2, flankers: [1, 5, 7, 8], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.date, .small, 2, 0, Kit.bare),
                KitItem(.calendar, .large, 0, 1), KitItem(.todo, .medium, 2, 1, Kit.list("this week's intentions")),
                KitItem(.nextEvent, .medium, 2, 2), KitItem(.weather, .small, 5, 0),
                KitItem(.habits, .medium, 0, 3), KitItem(.photo, .small, 2, 3, picture("analog-studio")),
                KitItem(.photo, .small, 3, 3, picture("rose-still-life")),
             ]),
        make("studyMargins", "Study Margins", "White paper, a clear agenda and one place to concentrate.",
             wallpaper: wall("ivory-paper"), card: 0xFCFAF5, ink: 0x363D47, accent: 0x6684A4, palette: .sky,
             font: .standard, radius: 12, collections: [.minimal, .designer], tags: "study white agenda school focus checklist reading",
             philosophy: "Time and the calendar sit in the middle. A study checklist and reading card occupy the left; photos and quick app access finish the right edge.",
             hero: 2, flankers: [1, 4, 5, 7], kit: [
                KitItem(.clock, .medium, 2, 0, Kit.bare), KitItem(.focus, .small, 0, 0),
                KitItem(.todo, .large, 0, 1, Kit.list("study agenda")), KitItem(.calendar, .medium, 2, 1, Kit.bare),
                KitItem(.photo, .small, 5, 0, picture("botanical-paper")), KitItem(.weather, .small, 5, 1),
                KitItem(.reading, .medium, 0, 3), KitItem(.battery, .small, 5, 2), KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("sageAtelier", "Sage Atelier", "Botanical paper, olive details and room for a slower day.",
             wallpaper: wall("botanical-paper"), card: 0xEDEFE4, ink: 0x384A3B, accent: 0x6F8554, palette: .matcha,
             style: .handwritten, radius: 18, sticker: .flower, collections: [.minimal, .zen, .colourAndLight], tags: "botanical sage green neutral nature flowers atelier",
             philosophy: "A leafy still life supplies the wallpaper's natural focal point. Olive cards, cream frames and a small flower ornament gather at the opposite edge.",
             hero: 3, flankers: [1, 2, 5, 7], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 2, 0), KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .large, 0, 1, picture("cinema-alpine")), KitItem(.todo, .medium, 2, 1, Kit.list("grow slowly")),
                KitItem(.sticker, .small, 2, 2), KitItem(.quote, .medium, 0, 3, Kit.words("leave room to grow", style: .handwritten, bare: true)),
                KitItem(.daylight, .small, 5, 3), KitItem(.nowPlaying, .medium, 2, 3),
             ]),
        make("sundayPaper", "Sunday Paper", "Botanical still lifes, small serif headlines and an analog soundtrack.",
             wallpaper: wall("ivory-paper"), card: 0xF9F5ED, ink: 0x403F3B, accent: 0x8C795B, palette: .mocha,
             radius: 8, filter: .warm, collections: [.indie, .retro, .minimal], tags: "editorial newspaper sunday botanical cream cassette music",
             philosophy: "A floral hero and silver cassette establish an editorial music desk. Serif quotations replace decorative noise; the right edge carries the day's useful details.",
             hero: 2, flankers: [1, 4, 6, 8], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.date, .small, 2, 0, Kit.bare),
                KitItem(.photo, .large, 0, 1, picture("botanical-paper")),
                KitItem(.quote, .medium, 2, 1, Kit.words("The quiet edition.", style: .editorial, kicker: "SUNDAY PAPER")),
                KitItem(.calendar, .small, 5, 0), KitItem(.cassette, .medium, 2, 2), KitItem(.weather, .small, 5, 1),
                KitItem(.nowPlaying, .medium, 4, 2), KitItem(.photo, .small, 0, 3, picture("analog-studio")),
                KitItem(.shortcuts, .medium, 1, 3, shortcuts),
             ]),
        make("paperMuse", "Paper Muse", "Monochrome prints, outlined stars and a little handwritten poetry.",
             wallpaper: wall("ivory-paper"), card: 0xFEFCF8, ink: 0x383638, accent: 0x86715C, palette: .mono,
             style: .script, radius: 10, filter: .mono, collections: [.indie, .designer], tags: "monochrome scrapbook polaroid white stars music",
             philosophy: "Overlapping prints and an outlined star give the white desktop a scrapbook silhouette. Bare time and a record balance its loose photo cluster.",
             hero: 2, title: 5, flankers: [1, 3, 4, 7], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 5, 0),
                KitItem(.polaroids, .large, 0, 1, prints(["track-day", "analog-studio", "botanical-paper"])),
                KitItem(.sticker, .small, 2, 1), KitItem(.charm, .small, 5, 1, ornament(.star)),
                KitItem(.wordArt, .medium, 2, 2, Kit.wordArt("collect moments", .chrome, style: .script)),
                KitItem(.vinyl, .medium, 4, 2), KitItem(.weather, .small, 0, 3), KitItem(.todo, .medium, 4, 3, Kit.list("notes to self")),
             ]),
        make("silverStereo", "Silver Stereo", "Liquid silver, monochrome photography and a hardware-like soundtrack.",
             wallpaper: wall("silver-current"), card: 0x26282E, ink: 0xF4F5F8, accent: 0xACBEDA, palette: .mono,
             font: .standard, material: .glass, filter: .mono, dark: true, collections: [.featured, .night, .musicIcons], tags: "monochrome music silver chrome cassette swirl ring",
             philosophy: "Black-and-white photographs, a brushed cassette and compact live readings frame a wide silver current. The center stays open for the wallpaper.",
             hero: 2, flankers: [1, 3, 4, 5], kit: [
                KitItem(.clock, .medium, 0, 0), KitItem(.battery, .small, 2, 0),
                KitItem(.photo, .medium, 0, 1, picture("analog-studio", frame: .fullBleed)), KitItem(.calendar, .small, 5, 0),
                KitItem(.metric, .small, 0, 2, metric(.cpu, bare: false)), KitItem(.metric, .small, 1, 2, metric(.memory, bare: false)),
                KitItem(.cassette, .medium, 4, 1), KitItem(.visualizer, .medium, 4, 2, { w, _ in w.options.visualizer = .ring }),
                KitItem(.shortcuts, .medium, 4, 3, panelShortcuts),
             ]),
        make("nocturneFM", "Nocturne FM", "Indigo glass, a midnight photograph and one last record.",
             wallpaper: .photo(.bundled("cinema-midnight.jpg")), card: 0x202539, ink: 0xEBEEFA, accent: 0xA398DB, palette: .midnight,
             font: .standard, style: .elegant, material: .glass, dark: true, collections: [.night, .ambient, .musicIcons], tags: "lofi nocturne music midnight indigo cassette vinyl radio",
             philosophy: "A photograph and record gather on the left; small time, weather and music controls sit on the right. Dim indigo glass keeps the nocturnal scene visible.",
             hero: 2, flankers: [1, 3, 6, 7], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.moon, .small, 2, 0),
                KitItem(.photo, .large, 0, 1, picture("cinema-midnight", frame: .fullBleed)),
                KitItem(.calendar, .small, 5, 0), KitItem(.vinyl, .medium, 4, 1), KitItem(.nowPlaying, .medium, 4, 2),
                KitItem(.weather, .small, 5, 3), KitItem(.quote, .small, 0, 3, Kit.words("after hours", style: .script, bare: true)),
                KitItem(.cassette, .medium, 1, 3),
             ]),
        make("cherryArchive", "Cherry Archive", "Deep cherry, intimate prints and a record collection after dark.",
             wallpaper: .art(.init(style: .film, palette: .cherry)), card: 0x3D2028, ink: 0xFFE7EB, accent: 0xF190A6, palette: .cherry,
             style: .script, clock: .analog, material: .frosted, filter: .warm, dark: true, collections: [.night, .rnb, .musicIcons], tags: "cherry red romance dark archive music collage",
             philosophy: "A dense left-hand print collage pairs with cherry utility cards and an analog face. The center-right is deliberately quiet.",
             hero: 2, title: 5, flankers: [0, 1, 3, 7], kit: [
                KitItem(.clock, .small, 0, 0), KitItem(.calendar, .small, 1, 0),
                KitItem(.polaroids, .large, 0, 1, prints(["rose-still-life", "analog-studio", "track-day"])),
                KitItem(.weather, .small, 5, 0), KitItem(.todo, .medium, 4, 1, Kit.list("after-dark plans")),
                KitItem(.wordArt, .medium, 2, 1, Kit.wordArt("love, archived", .gold, style: .script)),
                KitItem(.nowPlaying, .medium, 0, 3), KitItem(.charm, .small, 2, 3, ornament(.heart)), KitItem(.vinyl, .medium, 4, 3),
             ]),
        make("roseLeopard", "Rose Leopard", "Dusty rose, an animal-print clock and a polished little photo corner.",
             wallpaper: wall("rose-heart"), card: 0xE9D2D5, ink: 0x4A303D, accent: 0x946279, palette: .diva,
             style: .luxe, clock: .analog, radius: 20, filter: .mono, sticker: .crown,
             collections: [.luxury, .pop, .colourAndLight], tags: "rose leopard glam pink animal print fashion",
             philosophy: "A leopard-backed clock is the signature piece. Monochrome prints and rose utility cards build two restrained clusters around the pink wallpaper.",
             hero: 3, flankers: [0, 1, 2, 5], kit: [
                KitItem(.clock, .small, 0, 0, { w, _ in w.material = .art; w.options.art = .init(style: .leopard, palette: .diva) }),
                KitItem(.calendar, .small, 1, 0), KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .large, 0, 1, picture("rose-still-life")), KitItem(.todo, .medium, 4, 1, Kit.list("the essentials")),
                KitItem(.sticker, .small, 2, 2), KitItem(.shortcuts, .medium, 4, 2, shortcuts),
                KitItem(.quote, .medium, 0, 3, Kit.words("your own kind of iconic", style: .luxe)), KitItem(.nowPlaying, .medium, 4, 3),
             ]),
        make("copperConsole", "Copper Console", "Obsidian ink, copper motion and a transparent technical dashboard.",
             wallpaper: wall("copper-flow"), card: 0x241C18, ink: 0xFFF1E5, accent: 0xEDB359, palette: .ember,
             font: .monospaced, style: .modern, material: .glass, radius: 12, dark: true,
             collections: [.featured, .night, .developer], tags: "transparent technical dashboard copper cpu ram storage hud",
             philosophy: "Unboxed time and live CPU, memory and storage readings use amber accents. Widgets stay at the edges of the black-and-copper fluid artwork.",
             hero: 0, flankers: [1, 2, 3, 4], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.metric, .small, 0, 1, metric(.cpu)),
                KitItem(.metric, .small, 1, 1, metric(.memory)), KitItem(.metric, .small, 0, 2, metric(.storage)),
                KitItem(.battery, .small, 1, 2, Kit.bare), KitItem(.weather, .medium, 4, 0, Kit.bare),
                KitItem(.calendar, .medium, 4, 1, Kit.bare), KitItem(.nowPlaying, .medium, 0, 3, Kit.bare),
                KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("quietCircuit", "Quiet Circuit", "Graphite glass, a silver current and the essentials in the margins.",
             wallpaper: wall("silver-current"), card: 0x24262B, ink: 0xF3F4F6, accent: 0xA9C1D3, palette: .shadow,
             font: .standard, style: .modern, material: .glass, dark: true,
             collections: [.night, .minimal, .developer], tags: "minimal dark monochrome swirl personal system graphite",
             philosophy: "A compact upper-left group holds time, battery and a photograph. Expressive app shortcuts sit opposite; most of the silver wallpaper remains uninterrupted.",
             hero: 2, flankers: [1, 3, 4, 7], kit: [
                KitItem(.clock, .medium, 0, 0), KitItem(.battery, .small, 2, 0),
                KitItem(.photo, .medium, 0, 1, picture("track-day", frame: .fullBleed)),
                KitItem(.metric, .small, 2, 1, metric(.cpu, bare: false)), KitItem(.calendar, .small, 5, 0, Kit.bare),
                KitItem(.quote, .medium, 0, 2, Kit.words("less, with intention", style: .modern, bare: true)),
                KitItem(.shortcuts, .medium, 4, 1, panelShortcuts), KitItem(.weather, .small, 5, 3, Kit.bare),
             ]),
        make("blueprintNight", "Blueprint Night", "Cobalt glass, precise type and a desk for deep work.",
             wallpaper: .photo(.bundled("cinema-orbit.jpg")), card: 0x152C43, ink: 0xE2F5FF, accent: 0x78C3ED, palette: .ocean,
             font: .monospaced, style: .typewriter, material: .glass, radius: 10, dark: true,
             collections: [.night, .developer, .cosmic], tags: "blueprint cobalt developer terminal focus cosmic system",
             philosophy: "Precise mono type and cool glass frame an orbital photograph. A terminal, system readings and a focus timer form a useful lower working band.",
             hero: 3, flankers: [1, 2, 5, 6], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 2, 0), KitItem(.weather, .small, 5, 0),
                KitItem(.terminal, .large, 0, 1), KitItem(.todo, .medium, 4, 1, Kit.list("the next build")),
                KitItem(.metric, .small, 4, 2, metric(.memory)), KitItem(.battery, .small, 5, 2),
                KitItem(.focus, .medium, 0, 3), KitItem(.nowPlaying, .medium, 4, 3),
             ]),
        make("goodEnergy", "Good Energy", "Oversized lavender words and a small, focused midnight toolkit.",
             wallpaper: .art(.init(style: .film, palette: .shadow)), card: 0x282635, ink: 0xF1EAFF, accent: 0xB5A0EB, palette: .lavender,
             font: .condensed, style: .poster, clock: .flip, material: .paper, radius: 16, dark: true,
             collections: [.night, .minimal, .designer], tags: "typography poster affirmation good energy focus lilac",
             philosophy: "A huge central affirmation carries the design. A few lavender utility cards around its perimeter support concentration without competing with the type.",
             hero: 3, flankers: [0, 1, 2, 5], kit: [
                KitItem(.clock, .small, 0, 0), KitItem(.calendar, .small, 1, 0), KitItem(.weather, .small, 5, 0),
                KitItem(.quote, .large, 2, 1, Kit.words("GOOD\nENERGY", style: .poster, bare: true)),
                KitItem(.todo, .medium, 0, 1, Kit.list("make it happen")), KitItem(.focus, .small, 5, 1),
                KitItem(.nowPlaying, .medium, 0, 3), KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("cobaltPaddock", "Cobalt Paddock", "A midnight garage, cyan glass and a clear view of the car.",
             wallpaper: wall("cobalt-garage"), card: 0x142B42, ink: 0xE7F7FF, accent: 0x72C9EF, palette: .bleu,
             font: .standard, style: .modern, material: .glass, radius: 16, dark: true,
             collections: [.featured, .night, .cinematic], tags: "motorsport racing formula paddock blue garage car world clock",
             philosophy: "Cyan utility panels surround the garage's car silhouette. World time, weather, a track photograph and music keep the motorsport desktop useful.",
             hero: 3, flankers: [1, 2, 4, 7], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 2, 0), KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .medium, 0, 1, picture("track-day", frame: .fullBleed)),
                KitItem(.battery, .small, 0, 2), KitItem(.clock, .medium, 4, 1, clock(.world)),
                KitItem(.nowPlaying, .medium, 4, 2), KitItem(.stopwatch, .small, 1, 2),
                KitItem(.shortcuts, .medium, 0, 3, shortcuts),
             ]),
        make("apexJournal", "Apex Journal", "Cream paper, monochrome racing prints and a driver's notebook.",
             wallpaper: wall("ivory-paper"), card: 0xF4F0E8, ink: 0x353634, accent: 0x9B7656, palette: .mocha,
             radius: 8, filter: .mono, collections: [.cinematic, .designer, .retro], tags: "motorsport racing editorial cream journal monochrome collage",
             philosophy: "Racing photographs form an editorial collage with fine serif words, script and stars. A generous notebook card balances the photographic left side.",
             hero: 2, title: 8, flankers: [1, 4, 5, 7], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 2, 0),
                KitItem(.photo, .large, 0, 1, picture("track-day", frame: .inset)),
                KitItem(.todo, .large, 4, 1, Kit.list("the driver's notebook")), KitItem(.sticker, .small, 3, 0),
                KitItem(.photo, .small, 2, 1, picture("cobalt-garage")),
                KitItem(.quote, .medium, 2, 2, Kit.words("Find your line.", style: .editorial)),
                KitItem(.stopwatch, .small, 0, 3), KitItem(.wordArt, .medium, 1, 3, Kit.wordArt("on the limit", .chrome, style: .script)),
                KitItem(.nowPlaying, .medium, 4, 3),
             ]),
        make("pitlaneWhite", "Pitlane White", "One wide racing photograph, bare black time and plenty of white space.",
             wallpaper: wall("ivory-paper"), card: 0xFAF8F2, ink: 0x2E3034, accent: 0x766C60, palette: .mono,
             font: .standard, radius: 6, filter: .mono, collections: [.cinematic, .minimal], tags: "white minimal racing motorsport car hero photography",
             philosophy: "A wide car photograph and oversized bare clock create the hierarchy. A short quote, film stills and small utility cards complete a sparse white desk.",
             hero: 2, flankers: [1, 3, 5, 6], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare), KitItem(.calendar, .small, 5, 0),
                KitItem(.photo, .medium, 0, 1, picture("track-day", frame: .fullBleed)),
                KitItem(.photo, .small, 0, 2, picture("cobalt-garage")),
                KitItem(.quote, .medium, 1, 2, Kit.words("Precision is a practice.", style: .editorial)),
                KitItem(.weather, .small, 5, 1), KitItem(.stopwatch, .small, 5, 2), KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("redlineClub", "Redline Club", "Carbon, crimson details and a compact race-day control room.",
             wallpaper: .art(.init(style: .film, palette: .emberCharcoal)), card: 0x2A2025, ink: 0xFFEFF0, accent: 0xEE6B75, palette: .emberCharcoal,
             font: .condensed, style: .poster, clock: .flip, material: .paper, radius: 12, dark: true,
             collections: [.night, .cinematic, .rock], tags: "redline crimson racing motorsport carbon stopwatch race day",
             philosophy: "A track photograph meets a crimson flip clock and race-day timer. Bold condensed words and quiet carbon cards keep the composition energetic and legible.",
             hero: 2, flankers: [0, 1, 4, 6], kit: [
                KitItem(.clock, .small, 0, 0), KitItem(.stopwatch, .small, 1, 0),
                KitItem(.photo, .large, 0, 1, picture("track-day", frame: .fullBleed)),
                KitItem(.quote, .medium, 2, 0, Kit.words("CHASE THE APEX", style: .poster, bare: true)),
                KitItem(.calendar, .small, 5, 0), KitItem(.todo, .medium, 4, 1, Kit.list("race-day checklist")),
                KitItem(.weather, .small, 5, 2), KitItem(.nowPlaying, .medium, 0, 3), KitItem(.shortcuts, .medium, 4, 3, shortcuts),
             ]),
        make("goldenInterlude", "Golden Interlude", "Sunset glass, world time and a brief pause by the coast.",
             wallpaper: .photo(.bundled("cinema-coast.jpg")), card: 0x493F3E, ink: 0xFFF4E8, accent: 0xF2C39A, palette: .sunset,
             font: .standard, style: .elegant, clock: .analog, material: .glass, radius: 22, dark: true,
             collections: [.cinematic, .ambient, .colourAndLight], tags: "sunset native glass coast world analog clock golden hour",
             philosophy: "Warm translucent calendar, weather, reminders and world clocks form a compact central cluster. The coastal photograph supplies all the atmosphere.",
             hero: 0, flankers: [1, 2, 5, 6], kit: [
                KitItem(.calendar, .medium, 1, 0), KitItem(.clock, .small, 3, 0), KitItem(.weather, .small, 4, 0),
                KitItem(.todo, .medium, 1, 1, Kit.list("before the sun sets")), KitItem(.clock, .medium, 3, 1, clock(.world)),
                KitItem(.daylight, .small, 1, 2), KitItem(.battery, .small, 4, 2), KitItem(.nowPlaying, .medium, 2, 2),
             ]),
    ]
}
