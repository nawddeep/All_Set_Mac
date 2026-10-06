import Foundation

/// Football and music worlds: whole desktops inspired by the colors, eras and
/// moods fans know, packed edge to edge with the new live widgets. They name
/// no one and copy nothing: no photos of real people, crests, logos, album
/// art or lyrics. Photos are CC0 places and things; the words are our own.
extension WidgetTheme {
    public static let fandom: [WidgetTheme] = [
        seven, redSeven, galactico, albiceleste, oRei, sambaNeon, wonderkid, bleuRoyal, milanoNights, legends, miamiPink, matchday,
        americana, coastline, violetNoir, rageMode, sadHours, slimeGreen, deepBlue, crimsonNights, opiumPunk, blondSummer,
    ]

    private static func library(_ names: String...) -> [WebPhoto] { names.flatMap(CuratedBackgrounds.collection) }

    private static func backdropPhoto(_ collection: String, _ index: Int) -> WallpaperSource {
        let photos = CuratedBackgrounds.collection(collection)
        return .photo(.web(photos.isEmpty ? CuratedBackgrounds.suggestion(0) : photos[index % photos.count]))
    }

    // MARK: Football

    /// Portugal's number seven: red and green under floodlights, gold on top.
    public static let seven = WidgetTheme(
        id: "seven", title: "Seven", tagline: "Red, green and gold under the floodlights. Dream big, work harder.",
        material: .dark, card: WidgetColor(hex: 0x0E0A0B), ink: WidgetColor(hex: 0xF4EDE4), accent: WidgetColor(hex: 0xE8C15A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xE8C15A),
        font: .condensed, cornerRadius: 16, textStyle: .poster, clockFace: .flip, palette: .redGreen, photoFilter: .none,
        noteColor: .yellow, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "soccerball",
        wallpaper: .art(ArtPiece(style: .stadium, palette: .redGreen)),
        photos: library("Stadium Nights", "On the Pitch", "Golden Goal"),
        kit: [
            KitItem(.jersey, .large, 0, 0, Kit.player("LEGEND", 7, kit: "Red & Green", tagline: "DREAM BIG")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Seven", .gold, style: .script)),
            KitItem(.clock, .small, 4, 0),
            KitItem(.photo, .small, 5, 0, Kit.photo(1)),
            KitItem(.playerCard, .large, 2, 1, Kit.player("LEGEND", 7, kit: "Red & Green", tagline: "WORK HARDER", rating: 94,
                                                            finish: .gold, stats: [90, 95, 82, 88, 35, 86])),
            KitItem(.milestone, .medium, 4, 1, Kit.milestone(900, "+", "CAREER GOALS", "and counting")),
            KitItem(.scoreboard, .medium, 0, 2, Kit.match("POR", "ESP", 0xC8102E, 0xF1BF00, "FRIENDLY", inDays: 4)),
            KitItem(.photo, .medium, 4, 2, Kit.photo(2)),
            KitItem(.quote, .medium, 0, 3, Kit.words("Dream big.\nWork harder.", style: .poster)),
            KitItem(.focus, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.photo, .small, 5, 3, Kit.photo(8)),
        ])

    /// The white-and-gold era: royal nights, trophies on black, fine serif.
    public static let galactico = WidgetTheme(
        id: "galactico", title: "Galáctico", tagline: "White and gold, trophies on black, royal European nights.",
        material: .light, card: WidgetColor(hex: 0xF6F3EC), ink: WidgetColor(hex: 0x1C2440), accent: WidgetColor(hex: 0xB8902F),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xE8C15A),
        font: .serif, cornerRadius: 18, textStyle: .luxe, clockFace: .minimal, palette: .royal, photoFilter: .none,
        noteColor: .yellow, sticker: .crown, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "crown.fill",
        wallpaper: backdropPhoto("Golden Goal", 4),
        photos: library("Golden Goal", "Stadium Nights"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Galáctico", .gold, style: .luxe)),
            KitItem(.jersey, .medium, 2, 0, Kit.player("LEGEND", 7, kit: "Royal White", tagline: "WHITE & GOLD")),
            KitItem(.clock, .small, 4, 0, Kit.bare),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.playerCard, .large, 0, 1, Kit.player("LEGEND", 7, kit: "Royal White", tagline: "ROYAL NIGHTS", rating: 97,
                                                            finish: .legend, stats: [91, 95, 83, 89, 34, 85])),
            KitItem(.photo, .large, 2, 1, Kit.photo(5)),
            KitItem(.milestone, .small, 4, 1, Kit.both(Kit.milestone(5, "×", "EUROPEAN CROWNS", ""), Kit.dark)),
            KitItem(.calendar, .small, 5, 1),
            KitItem(.ticket, .medium, 4, 2, Kit.ticket("EUROPEAN NIGHT", "Under the white lights", venue: "The Royal Stadium",
                                                        seat: "EAST · ROW 7", inDays: 12, stripe: 0xB8902F)),
            KitItem(.nowPlaying, .medium, 0, 3),
            KitItem(.quote, .medium, 2, 3, Kit.words("Class is permanent.", style: .luxe)),
            KitItem(.weather, .medium, 4, 3),
        ])

    /// The young number seven in red: rainy floodlit nights and step-overs.
    public static let redSeven = WidgetTheme(
        id: "redSeven", title: "Red Seven", tagline: "The young number seven in red: rainy floodlit nights and step-overs.",
        material: .dark, card: WidgetColor(hex: 0x120204), ink: WidgetColor(hex: 0xFFF3F0), accent: WidgetColor(hex: 0xD0021B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF3B3B),
        font: .condensed, cornerRadius: 16, textStyle: .poster, clockFace: .flip, palette: .classicRed, photoFilter: .none,
        noteColor: .pink, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "7.circle.fill",
        wallpaper: .art(ArtPiece(style: .rain, palette: .classicRed)),
        photos: library("Stadium Nights", "On the Pitch"),
        kit: [
            KitItem(.photo, .large, 0, 0, Kit.photo(0)),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("No. 7", .chrome, style: .poster)),
            KitItem(.clock, .medium, 4, 0),
            KitItem(.playerCard, .large, 2, 1, Kit.player("THE SEVEN", 7, kit: "Classic Red", tagline: "MANCHESTER NIGHTS", rating: 91,
                                                            finish: .gold, stats: [93, 87, 78, 91, 32, 75])),
            KitItem(.jersey, .medium, 4, 1, Kit.player("LEGEND", 7, kit: "Classic Red", tagline: "NUMBER SEVEN")),
            KitItem(.photo, .medium, 0, 2, Kit.photo(1)),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(145, "", "GOALS IN RED", "across two spells")),
            KitItem(.photo, .small, 0, 3, Kit.photo(2)),
            KitItem(.photo, .small, 1, 3, Kit.photo(3)),
            KitItem(.scoreboard, .medium, 2, 3, Kit.match("MUN", "CHE", 0xD0021B, 0x034694, "FINAL · 2008", score: (1, 1))),
            KitItem(.nowPlaying, .medium, 4, 3),
        ])

    /// The boy wonder: claret and blue, stadium bokeh and the number nineteen.
    public static let wonderkid = WidgetTheme(
        id: "wonderkid", title: "Wonderkid", tagline: "Claret and blue, stadium bokeh and a teenager changing the game.",
        material: .frosted, card: WidgetColor(hex: 0x0B0E2A), ink: WidgetColor(hex: 0xFFFFFF), accent: WidgetColor(hex: 0xEDBB00),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFD54A),
        font: .rounded, cornerRadius: 22, textStyle: .bold, clockFace: .digital, palette: .blaugrana, photoFilter: .none,
        noteColor: .blue, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xEDBB00), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .bokeh, palette: .blaugrana)),
        photos: library("On the Pitch", "Stadium Nights"),
        kit: [
            KitItem(.playerCard, .large, 0, 0, Kit.player("WONDERKID", 19, kit: "Claret & Blue", tagline: "BORN FOR THIS", rating: 90,
                                                            finish: .holo, stats: [90, 82, 86, 92, 30, 60])),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Wonderkid", .holo, style: .bold)),
            KitItem(.jersey, .small, 4, 0, Kit.player("WONDERKID", 19, kit: "Claret & Blue")),
            KitItem(.clock, .small, 5, 0),
            KitItem(.photo, .large, 2, 1, Kit.photo(0)),
            KitItem(.photo, .medium, 4, 1, Kit.photo(1)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(2)),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(17, "", "YEARS OLD", "and already a star")),
            KitItem(.visualizer, .medium, 0, 3, Kit.visualizer(.bars)),
            KitItem(.quote, .medium, 2, 3, Kit.words("No limits.\nJust vibes.", style: .bold)),
            KitItem(.photo, .small, 4, 3, Kit.photo(3)),
            KitItem(.calendar, .small, 5, 3),
        ])

    /// Paris at night in navy and gold: speed, the number ten, royal blue.
    public static let bleuRoyal = WidgetTheme(
        id: "bleuRoyal", title: "Bleu Royal", tagline: "Paris at night in navy and gold: pure speed and the number ten.",
        material: .glass, card: WidgetColor(hex: 0x0C1A3F), ink: WidgetColor(hex: 0xFFFFFF), accent: WidgetColor(hex: 0xE8C15A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xF3D36B),
        font: .expanded, cornerRadius: 18, textStyle: .modern, clockFace: .stacked, palette: .bleu, photoFilter: .none,
        noteColor: .blue, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .skyline, palette: .bleu)),
        photos: library("Stadium Nights", "On the Pitch"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Bleu Royal", .gold, style: .modern)),
            KitItem(.clock, .medium, 2, 0),
            KitItem(.jersey, .medium, 4, 0, Kit.player("VITESSE", 10, kit: "Navy Bleu", tagline: "SPEED IS POWER")),
            KitItem(.photo, .large, 0, 1, Kit.photo(0)),
            KitItem(.playerCard, .large, 2, 1, Kit.player("VITESSE", 10, kit: "Navy Bleu", tagline: "PARIS NIGHTS", rating: 92,
                                                            finish: .night, stats: [97, 90, 80, 92, 36, 77])),
            KitItem(.scoreboard, .medium, 4, 1, Kit.match("FRA", "ARG", 0x1C2A5A, 0x75AADB, "ROUND OF 16 · 2018", score: (4, 3))),
            KitItem(.photo, .medium, 4, 2, Kit.photo(1)),
            KitItem(.quote, .medium, 0, 3, Kit.words("Fast. Fearless.\nFrench.", style: .modern)),
            KitItem(.nowPlaying, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.weather, .small, 5, 3),
        ])

    /// Red and black stripes, flares in the stands and pure elegance.
    public static let milanoNights = WidgetTheme(
        id: "milanoNights", title: "Milano Nights", tagline: "Red and black stripes, flares in the stands and pure elegance.",
        material: .dark, card: WidgetColor(hex: 0x0C0606), ink: WidgetColor(hex: 0xF8EEEE), accent: WidgetColor(hex: 0xC8102E),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF5A4A),
        font: .serif, cornerRadius: 12, textStyle: .luxe, clockFace: .minimal, palette: .rossoneri, photoFilter: .none,
        noteColor: .pink, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .smoke, palette: .rossoneri)),
        photos: library("Stadium Nights", "Smoke"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Milano", .gold, style: .luxe)),
            KitItem(.photo, .large, 2, 0, Kit.photo(0)),
            KitItem(.playerCard, .large, 4, 0, Kit.player("ELEGANZA", 22, kit: "Red & Black Stripes", tagline: "RED & BLACK NIGHTS",
                                                            rating: 93, finish: .night, stats: [88, 86, 92, 93, 40, 76])),
            KitItem(.jersey, .medium, 0, 1, Kit.player("CAPITANO", 3, kit: "Red & Black Stripes", tagline: "ONE CLUB, ONE LIFE")),
            KitItem(.photo, .large, 0, 2, Kit.photo(1)),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(2, caption: "SAN SIRO · 2007")),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(7, "", "EUROPEAN CROWNS", "in red and black")),
            KitItem(.quote, .medium, 2, 3, Kit.words("Elegance is\na way of playing.", style: .luxe)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.clock, .small, 5, 3),
        ])

    /// The all-time greats in black and gold, embers rising like applause.
    public static let legends = WidgetTheme(
        id: "legends", title: "Hall of Fame", tagline: "The all-time greats in black and gold, embers rising like applause.",
        material: .dark, card: WidgetColor(hex: 0x0A0806), ink: WidgetColor(hex: 0xF6EBD0), accent: WidgetColor(hex: 0xE8C15A),
        wallpaperInk: WidgetColor(hex: 0xFFF1C1), wallpaperAccent: WidgetColor(hex: 0xE8C15A),
        font: .serif, cornerRadius: 10, textStyle: .luxe, clockFace: .analog, palette: .hallOfFame, photoFilter: .none,
        noteColor: .yellow, sticker: .crown, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "crown.fill",
        wallpaper: .art(ArtPiece(style: .embers, palette: .hallOfFame)),
        photos: library("Golden Goal", "Stadium Nights"),
        kit: [
            KitItem(.photo, .large, 0, 0, Kit.photo(0)),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Hall of Fame", .gold, style: .luxe)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.clock, .small, 5, 0),
            KitItem(.photo, .medium, 2, 1, Kit.photo(4)),
            KitItem(.photo, .large, 4, 1, Kit.photo(5)),
            KitItem(.playerCard, .medium, 0, 2, Kit.player("THE GREATEST", 10, kit: "Royal White", tagline: "FOREVER", rating: 99,
                                                             finish: .legend, stats: [95, 98, 96, 98, 50, 85])),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(1, caption: "THE GREATS · 1958–2022")),
            KitItem(.photo, .medium, 0, 3, Kit.photo(2)),
            KitItem(.quote, .medium, 2, 3, Kit.words("Legends never\nreally leave.", style: .luxe)),
            KitItem(.milestone, .medium, 4, 3, Kit.milestone(22, "", "WORLD CUPS", "every one a story")),
        ])

    /// Sky-blue stripes and a left foot like magic: the number ten.
    public static let albiceleste = WidgetTheme(
        id: "albiceleste", title: "Albiceleste", tagline: "Sky-blue stripes, the number ten and a little magic.",
        material: .frosted, card: WidgetColor(hex: 0x0E1B2E), ink: WidgetColor(hex: 0xF2F7FC), accent: WidgetColor(hex: 0x75AADB),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x9CCBF0),
        font: .rounded, cornerRadius: 20, textStyle: .bold, clockFace: .digital, palette: .skyWhite, photoFilter: .none,
        noteColor: .blue, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "star.fill",
        wallpaper: backdropPhoto("Stadium Nights", 0),
        photos: library("On the Pitch", "Stadium Nights", "Golden Goal"),
        kit: [
            KitItem(.jersey, .large, 0, 0, Kit.player("MAESTRO", 10, kit: "Sky Stripes", tagline: "PURE MAGIC")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("G.O.A.T.", .gold, style: .poster)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.clock, .small, 5, 0),
            KitItem(.pitch, .medium, 2, 1, Kit.match("ARG", "FRA", 0x75AADB, 0x1F3A93, "FINAL", inDays: nil)),
            KitItem(.playerCard, .medium, 4, 1, Kit.player("MAESTRO", 10, kit: "Sky Stripes", tagline: "LEFT FOOT MAGIC", rating: 96,
                                                             finish: .legend, stats: [85, 92, 94, 96, 38, 68])),
            KitItem(.photo, .medium, 0, 2, Kit.photo(0)),
            KitItem(.scoreboard, .medium, 2, 2, Kit.match("ARG", "FRA", 0x75AADB, 0x1F3A93, "FINAL · 2022", score: (3, 3))),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(45, "+", "TROPHIES", "the most ever")),
            KitItem(.nowPlaying, .medium, 0, 3),
            KitItem(.calendar, .small, 2, 3),
            KitItem(.weather, .small, 3, 3),
            KitItem(.photo, .medium, 4, 3, Kit.photo(3)),
        ])

    /// 1970 in color: canary yellow, green and blue, retro stripes, film.
    public static let oRei = WidgetTheme(
        id: "oRei", title: "O Rei", tagline: "The king's era: canary yellow, retro stripes and film grain.",
        material: .paper, card: WidgetColor(hex: 0xF3E9D2), ink: WidgetColor(hex: 0x1F3B1F), accent: WidgetColor(hex: 0x009C3B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFDF00),
        font: .serif, cornerRadius: 10, textStyle: .chunky, clockFace: .analog, palette: .canary, photoFilter: .vintage,
        noteColor: .yellow, sticker: .crown, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xFFDF00), iconSymbol: "crown.fill",
        wallpaper: .art(ArtPiece(style: .stripes, palette: .canary)),
        photos: library("Golden Goal", "On the Pitch"),
        kit: [
            KitItem(.sticker, .small, 0, 0),
            KitItem(.wordArt, .medium, 1, 0, Kit.wordArt("O Rei", .gold, style: .chunky)),
            KitItem(.scoreboard, .medium, 3, 0, Kit.match("BRA", "ITA", 0xFFD400, 0x1F5FBF, "FINAL · 1970", score: (4, 1))),
            KitItem(.clock, .small, 5, 0),
            KitItem(.jersey, .large, 0, 1, Kit.player("REI", 10, kit: "Canary", tagline: "1958 · 1962 · 1970")),
            KitItem(.vhs, .large, 2, 1, Kit.tape(1, caption: "MEXICO 1970")),
            KitItem(.playerCard, .medium, 4, 1, Kit.player("O REI", 10, kit: "Canary", tagline: "THE KING", rating: 98,
                                                             finish: .legend, stats: [93, 97, 90, 96, 50, 80])),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(1000, "+", "GOALS", "the king of them all")),
            KitItem(.quote, .medium, 0, 3, Kit.words("The beautiful game.", style: .chunky)),
            KitItem(.calendar, .small, 2, 3),
            KitItem(.photo, .small, 3, 3, Kit.photo(2)),
            KitItem(.nowPlaying, .medium, 4, 3),
        ])

    /// Flair in neon: canary yellow on a synth grid, skills and samba.
    public static let sambaNeon = WidgetTheme(
        id: "sambaNeon", title: "Samba Neon", tagline: "Canary yellow on a neon grid: skill, flair and samba.",
        material: .dark, card: WidgetColor(hex: 0x07100A), ink: WidgetColor(hex: 0xF5FFF0), accent: WidgetColor(hex: 0xFFDF00),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFE14D),
        font: .expanded, cornerRadius: 18, textStyle: .bold, clockFace: .digital, palette: .canary, photoFilter: .none,
        noteColor: .yellow, sticker: .bolt, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFDF00), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .synthwave, palette: .canary)),
        photos: library("On the Pitch", "Neon Green", "Concert Lights"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Flair", .neon, style: .script, color: 0xFFE14D)),
            KitItem(.playerCard, .large, 2, 0, Kit.player("FLAIR", 10, kit: "Canary", tagline: "SKILL IS A LANGUAGE", rating: 91,
                                                            finish: .neon, stats: [91, 85, 86, 94, 32, 62])),
            KitItem(.jersey, .small, 4, 0, Kit.player("SAMBA", 10, kit: "Canary")),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.visualizer, .medium, 0, 1, Kit.visualizer(.bars)),
            KitItem(.pitch, .medium, 4, 1, Kit.match("BRA", "ARG", 0xFFD400, 0x75AADB, "CLÁSSICO", inDays: 6)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(9)),
            KitItem(.photo, .medium, 2, 2, Kit.photo(4)),
            KitItem(.scoreboard, .medium, 4, 2, Kit.match("BRA", "ARG", 0xFFD400, 0x75AADB, "CLÁSSICO", inDays: 6)),
            KitItem(.clock, .medium, 0, 3, Kit.bare),
            KitItem(.focus, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.battery, .small, 5, 3),
        ])

    /// Pink and black by the ocean: palm silhouettes and a new chapter.
    public static let miamiPink = WidgetTheme(
        id: "miamiPink", title: "Miami Pink", tagline: "Pink and black, palms at night, a new chapter by the sea.",
        material: .dark, card: WidgetColor(hex: 0x0D0A0C), ink: WidgetColor(hex: 0xFFF0F6), accent: WidgetColor(hex: 0xF4A6C6),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF8FC2),
        font: .rounded, cornerRadius: 22, textStyle: .script, clockFace: .flip, palette: .miami, photoFilter: .none,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xF4A6C6), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .palms, palette: .miami)),
        photos: library("Palm Sunsets", "Neon Motels", "On the Pitch"),
        kit: [
            KitItem(.jersey, .medium, 0, 0, Kit.player("MIAMI", 10, kit: "Pink & Black", tagline: "NEW CHAPTER")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Miami Nights", .neon, style: .script, color: 0xFF8FC2)),
            KitItem(.clock, .medium, 4, 0),
            KitItem(.playerCard, .large, 0, 1, Kit.player("MIAMI", 10, kit: "Pink & Black", tagline: "PINK IS THE NEW GOLD", rating: 93,
                                                            finish: .neon, stats: [80, 90, 93, 94, 33, 64])),
            KitItem(.photo, .large, 2, 1, Kit.photo(0)),
            KitItem(.ticket, .medium, 4, 1, Kit.ticket("MATCH NIGHT", "Pink under the lights", venue: "Fort Lauderdale",
                                                        seat: "SEC 110 · ROW 10", inDays: 9, stripe: 0xF4A6C6)),
            KitItem(.scoreboard, .medium, 4, 2, Kit.match("MIA", "NYC", 0xF4A6C6, 0x6CACE4, "SEASON", inDays: 5)),
            KitItem(.nowPlaying, .medium, 0, 3),
            KitItem(.photo, .small, 2, 3, Kit.photo(14)),
            KitItem(.sticker, .small, 3, 3),
            KitItem(.weather, .medium, 4, 3),
        ])

    /// Any club, any league: the tactics board, the board and the ticket.
    public static let matchday = WidgetTheme(
        id: "matchday", title: "Matchday", tagline: "Floodlights, the tactics board and a ticket for Saturday.",
        material: .glass, card: WidgetColor(hex: 0x101418), ink: WidgetColor(hex: 0xFFFFFF), accent: WidgetColor(hex: 0x9BE564),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xBFD8FF),
        font: .condensed, cornerRadius: 14, textStyle: .poster, clockFace: .digital, palette: .floodlit, photoFilter: .none,
        noteColor: .green, sticker: .star, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "sportscourt.fill",
        wallpaper: .art(ArtPiece(style: .stadium, palette: .floodlit)),
        photos: library("Stadium Nights", "On the Pitch"),
        kit: [
            KitItem(.pitch, .large, 0, 0, Kit.match("RED", "BLU", 0xE0314B, 0x2F6BFF, "MATCHDAY", inDays: 2, formation: .f4231)),
            KitItem(.scoreboard, .medium, 2, 0, Kit.match("RED", "BLU", 0xE0314B, 0x2F6BFF, "MATCHDAY", inDays: 2)),
            KitItem(.clock, .small, 4, 0),
            KitItem(.weather, .small, 5, 0),
            KitItem(.ticket, .medium, 2, 1, Kit.ticket("DERBY DAY", "Kickoff under the lights", venue: "Home Ground",
                                                        seat: "NORTH STAND", inDays: 2, stripe: 0xE0314B)),
            KitItem(.photo, .medium, 4, 1, Kit.photo(0)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(3)),
            KitItem(.milestone, .medium, 2, 2, Kit.milestone(38, "", "GOALS THIS SEASON", "top of the league")),
            KitItem(.todo, .medium, 4, 2, Kit.list("matchday")),
            KitItem(.jersey, .small, 0, 3, Kit.player("CAPTAIN", 8, kit: "Orange Hoops")),
            KitItem(.calendar, .small, 1, 3),
            KitItem(.quote, .medium, 2, 3, Kit.words("Leave it all\non the pitch.", style: .poster)),
            KitItem(.focus, .medium, 4, 3),
        ])

    // MARK: Music

    /// Old Hollywood Americana: palms at dusk, cherry red, vintage cars, VHS.
    public static let americana = WidgetTheme(
        id: "americana", title: "Americana", tagline: "Palms at dusk, cherry red, vintage cars and a VHS summer.",
        material: .paper, card: WidgetColor(hex: 0xF6EEDF), ink: WidgetColor(hex: 0x3A1F1F), accent: WidgetColor(hex: 0xB3202A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFD1D6),
        font: .serif, cornerRadius: 14, textStyle: .script, clockFace: .analog, palette: .americana, photoFilter: .vintage,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xB3202A), iconSymbol: "heart.fill",
        wallpaper: backdropPhoto("Palm Sunsets", 6),
        photos: library("Americana", "Palm Sunsets", "Roses & Cherries", "Neon Motels"),
        kit: [
            KitItem(.vhs, .large, 0, 0, Kit.tape(13, caption: "HOLLYWOOD '94")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("sad girl summer", .neon, style: .script, color: 0xFF4D6D)),
            KitItem(.photo, .small, 4, 0, Kit.photo(0)),
            KitItem(.photo, .small, 5, 0, Kit.photo(22)),
            KitItem(.cassette, .medium, 2, 1, Kit.label("summertime mix")),
            KitItem(.photo, .medium, 4, 1, Kit.photo(29)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(3)),
            KitItem(.ticket, .medium, 2, 2, Kit.ticket("MIDNIGHT DRIVE-IN", "A double feature", venue: "Sunset Drive-In",
                                                        seat: "ROW 5 · CAR 12", inDays: 16, stripe: 0xB3202A)),
            KitItem(.photo, .small, 4, 2, Kit.photo(25)),
            KitItem(.sticker, .small, 5, 2),
            KitItem(.nowPlaying, .medium, 0, 3),
            KitItem(.quote, .medium, 2, 3, Kit.words("Kiss me in the Pacific light.", style: .typewriter)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.photo, .small, 5, 3, Kit.photo(9)),
        ])

    /// The California coast in pastel: salt air, polaroids and a cassette.
    public static let coastline = WidgetTheme(
        id: "coastline", title: "Coastline", tagline: "Pastel California coast: salt air, polaroids and a tape on repeat.",
        material: .paper, card: WidgetColor(hex: 0xFBF6EE), ink: WidgetColor(hex: 0x23364F), accent: WidgetColor(hex: 0x3B6E9E),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFF4E3),
        font: .serif, cornerRadius: 22, textStyle: .handwritten, clockFace: .minimal, palette: .coastline, photoFilter: .fade,
        noteColor: .blue, sticker: .moon, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "water.waves",
        wallpaper: backdropPhoto("Pacific Coast", 1),
        photos: library("Pacific Coast", "Palm Sunsets", "Blossom"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("ocean blue", .ice, style: .script)),
            KitItem(.clock, .medium, 2, 0, Kit.bare),
            KitItem(.moon, .small, 4, 0),
            KitItem(.weather, .small, 5, 0),
            KitItem(.polaroids, .large, 0, 1, Kit.prints(from: 0)),
            KitItem(.vhs, .medium, 2, 1, Kit.tape(3, caption: "PACIFIC COAST HWY")),
            KitItem(.cassette, .medium, 4, 1, Kit.label("coastline tape")),
            KitItem(.visualizer, .medium, 2, 2, Kit.visualizer(.mirror)),
            KitItem(.note, .medium, 4, 2, Kit.note("drive west until\nthe sky turns pink")),
            KitItem(.photo, .medium, 0, 3, Kit.photo(5)),
            KitItem(.quote, .medium, 2, 3, Kit.words("salt in my hair,\na song on repeat")),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.nowPlaying, .small, 5, 3),
        ])

    /// Black-and-white torch songs: roses, pearls, smoke and slow jazz.
    public static let violetNoir = WidgetTheme(
        id: "violetNoir", title: "Velvet Noir", tagline: "Black-and-white torch songs: roses, pearls, smoke and slow jazz.",
        material: .dark, card: WidgetColor(hex: 0x0B0A0C), ink: WidgetColor(hex: 0xEFE6DA), accent: WidgetColor(hex: 0x8E1B2E),
        wallpaperInk: WidgetColor(hex: 0xF4EDE4), wallpaperAccent: WidgetColor(hex: 0xC9A7B0),
        font: .serif, cornerRadius: 8, textStyle: .elegant, clockFace: .words, palette: .mono, photoFilter: .noir,
        noteColor: .pink, sticker: .heart, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE6E6E6), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .smoke, palette: .mono)),
        photos: library("Roses & Cherries", "Retro Things", "Gothic"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Velvet Noir", .chrome, style: .script)),
            KitItem(.photo, .large, 2, 0, Kit.photo(0)),
            KitItem(.vinyl, .medium, 4, 0),
            KitItem(.photo, .small, 0, 1, Kit.photo(12)),
            KitItem(.clock, .small, 1, 1),
            KitItem(.nowPlaying, .medium, 4, 1),
            KitItem(.vhs, .medium, 0, 2, Kit.tape(13, caption: "LIVE AT THE JAZZ CLUB")),
            KitItem(.quote, .medium, 2, 2, Kit.words("Pearls, cigarettes\nand slow jazz.", style: .elegant)),
            KitItem(.photo, .medium, 4, 2, Kit.photo(17)),
            KitItem(.sticker, .small, 0, 3),
            KitItem(.calendar, .small, 1, 3),
            KitItem(.visualizer, .medium, 2, 3, Kit.visualizer(.ring)),
            KitItem(.photo, .medium, 4, 3, Kit.photo(4)),
        ])

    /// Rage-era earth tones: smoke, fire, a crowd in the dark, it's lit.
    public static let rageMode = WidgetTheme(
        id: "rageMode", title: "Rage Mode", tagline: "Smoke, fire and a crowd in the dark. Earth tones, turned all the way up.",
        material: .dark, card: WidgetColor(hex: 0x160E09), ink: WidgetColor(hex: 0xF3E6D4), accent: WidgetColor(hex: 0xE3B26B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF8A3D),
        font: .condensed, cornerRadius: 12, textStyle: .poster, clockFace: .flip, palette: .rage, photoFilter: .warm,
        noteColor: .yellow, sticker: .flame, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE3B26B), iconSymbol: "flame.fill",
        wallpaper: .art(ArtPiece(style: .smoke, palette: .rage)),
        photos: library("Desert Fire", "Concert Lights", "Smoke"),
        kit: [
            KitItem(.wordArt, .large, 0, 0, Kit.wordArt("IT'S LIT", .fire, style: .poster)),
            KitItem(.visualizer, .medium, 2, 0, Kit.visualizer(.bars)),
            KitItem(.photo, .medium, 4, 0, Kit.photo(9)),
            KitItem(.vhs, .medium, 2, 1, Kit.tape(10, caption: "RAGE · LIVE")),
            KitItem(.photo, .small, 4, 1, Kit.photo(0)),
            KitItem(.sticker, .small, 5, 1),
            KitItem(.photo, .medium, 0, 2, Kit.photo(4)),
            KitItem(.ticket, .medium, 2, 2, Kit.ticket("RAGE NIGHT", "Mosh pit, front row", venue: "The Dome",
                                                        seat: "GA · PIT", inDays: 11, stripe: 0xC46A2B)),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.clock, .medium, 0, 3),
            KitItem(.photo, .medium, 2, 3, Kit.photo(18)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.battery, .small, 5, 3),
        ])

    /// Blue hours: rain on the window, a 3 a.m. tape, soft handwriting.
    public static let sadHours = WidgetTheme(
        id: "sadHours", title: "Sad Hours", tagline: "Rain on the window, a 3 a.m. tape and soft handwriting in blue.",
        material: .glass, card: WidgetColor(hex: 0x0A1633), ink: WidgetColor(hex: 0xE8F0FF), accent: WidgetColor(hex: 0x8FB3FF),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x8FB3FF),
        font: .standard, cornerRadius: 18, textStyle: .handwritten, clockFace: .digital, palette: .sadBlue, photoFilter: .cool,
        noteColor: .blue, sticker: .heart, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0x8FB3FF), iconSymbol: "cloud.rain.fill",
        wallpaper: .art(ArtPiece(style: .rain, palette: .sadBlue)),
        photos: library("Rainy Window", "Night Drive"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("sad hours", .neon, style: .handwritten, color: 0x4D8BFF)),
            KitItem(.clock, .medium, 2, 0),
            KitItem(.moon, .small, 4, 0),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.photo, .large, 0, 1, Kit.photo(0)),
            KitItem(.visualizer, .large, 2, 1, Kit.visualizer(.ring)),
            KitItem(.cassette, .medium, 4, 1, Kit.label("3am tape")),
            KitItem(.note, .medium, 4, 2, Kit.note("it's okay\nto not be okay")),
            KitItem(.photo, .medium, 0, 3, Kit.photo(12)),
            KitItem(.quote, .medium, 2, 3, Kit.words("the rain knows my name")),
            KitItem(.nowPlaying, .medium, 4, 3),
        ])

    /// Alt-pop in black and slime green: quiet, weird and glowing.
    public static let slimeGreen = WidgetTheme(
        id: "slimeGreen", title: "Slime Green", tagline: "Black and slime green: quiet, a little weird, glowing.",
        material: .dark, card: WidgetColor(hex: 0x050805), ink: WidgetColor(hex: 0xE9FFE0), accent: WidgetColor(hex: 0xB6FF3B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x9DFF4A),
        font: .rounded, cornerRadius: 20, textStyle: .bold, clockFace: .stacked, palette: .slime, photoFilter: .noir,
        noteColor: .green, sticker: .eye, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xB6FF3B), iconSymbol: "eye.fill",
        wallpaper: .art(ArtPiece(style: .smoke, palette: .slime)),
        photos: library("Neon Green", "Smoke", "Rainy Window"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("stay weird", .neon, style: .bold, color: 0x9DFF4A)),
            KitItem(.visualizer, .medium, 2, 0, Kit.visualizer(.mirror)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.clock, .small, 5, 0),
            KitItem(.photo, .large, 0, 1, Kit.photo(0)),
            KitItem(.photo, .small, 2, 1, Kit.photo(6)),
            KitItem(.photo, .small, 3, 1, Kit.photo(2)),
            KitItem(.cassette, .medium, 4, 1, Kit.label("whisper tape")),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(8, caption: "BEDROOM TAPES")),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.quote, .medium, 0, 3, Kit.words("quiet is a\nkind of loud", style: .bold)),
            KitItem(.calendar, .small, 2, 3),
            KitItem(.battery, .small, 3, 3),
            KitItem(.photo, .medium, 4, 3, Kit.photo(3)),
        ])

    /// Deep water blue: whales, the deep end and a ring of soft light.
    public static let deepBlue = WidgetTheme(
        id: "deepBlue", title: "Deep Blue", tagline: "The deep end: ocean blue, slow light and a ring that breathes.",
        material: .glass, card: WidgetColor(hex: 0x041526), ink: WidgetColor(hex: 0xE6F4FF), accent: WidgetColor(hex: 0x5BC0EB),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x9FE3FF),
        font: .standard, cornerRadius: 24, textStyle: .elegant, clockFace: .minimal, palette: .ocean, photoFilter: .cool,
        noteColor: .blue, sticker: .sparkles, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "drop.fill",
        wallpaper: backdropPhoto("Deep Water", 3),
        photos: library("Deep Water", "Rainy Window"),
        kit: [
            KitItem(.clock, .medium, 0, 0, Kit.bare),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("underwater", .ice, style: .script)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.moon, .small, 5, 0),
            KitItem(.visualizer, .large, 0, 1, Kit.visualizer(.ring)),
            KitItem(.photo, .medium, 2, 1, Kit.photo(1)),
            KitItem(.photo, .small, 4, 1, Kit.photo(5)),
            KitItem(.weather, .small, 5, 1),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(6, caption: "THE DEEP END")),
            KitItem(.cassette, .medium, 4, 2, Kit.label("ocean tape")),
            KitItem(.quote, .medium, 0, 3, Kit.words("float until the\nnoise goes quiet", style: .elegant)),
            KitItem(.nowPlaying, .medium, 2, 3),
            KitItem(.photo, .medium, 4, 3, Kit.photo(0)),
        ])

    /// Red neon after midnight: a city in crimson, a night drive, Vegas.
    public static let crimsonNights = WidgetTheme(
        id: "crimsonNights", title: "Crimson Nights", tagline: "Red neon after midnight: a crimson city and a long night drive.",
        material: .dark, card: WidgetColor(hex: 0x0C0204), ink: WidgetColor(hex: 0xFFE9EA), accent: WidgetColor(hex: 0xE11D2A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF3B47),
        font: .condensed, cornerRadius: 14, textStyle: .modern, clockFace: .digital, palette: .crimson, photoFilter: .none,
        noteColor: .pink, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFF3B47), iconSymbol: "sparkles",
        wallpaper: .art(ArtPiece(style: .skyline, palette: .crimson)),
        photos: library("Night Drive", "Neon Motels", "Concert Lights"),
        kit: [
            KitItem(.photo, .large, 0, 0, Kit.photo(0)),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("city of sin", .neon, style: .modern, color: 0xFF2D3F)),
            KitItem(.clock, .medium, 4, 0),
            KitItem(.visualizer, .medium, 2, 1, Kit.visualizer(.bars)),
            KitItem(.photo, .small, 4, 1, Kit.photo(19)),
            KitItem(.photo, .small, 5, 1, Kit.photo(17)),
            KitItem(.ticket, .medium, 0, 2, Kit.ticket("AFTER MIDNIGHT", "One night only", venue: "Las Vegas",
                                                        seat: "FLOOR · A1", inDays: 20, stripe: 0xE11D2A)),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(3, caption: "3:00 AM")),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.cassette, .medium, 0, 3, Kit.label("night drive")),
            KitItem(.photo, .medium, 2, 3, Kit.photo(5)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.weather, .small, 5, 3),
        ])

    /// Gothic punk in black and red: vamp letters, cathedrals, a mosh pit.
    public static let opiumPunk = WidgetTheme(
        id: "opiumPunk", title: "Vamp Punk", tagline: "Black and blood red: vamp letters, cathedrals and a mosh pit.",
        material: .dark, card: WidgetColor(hex: 0x050000), ink: WidgetColor(hex: 0xF2F2F2), accent: WidgetColor(hex: 0xFF1A1A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF2A2A),
        font: .standard, cornerRadius: 4, textStyle: .gothic, clockFace: .words, palette: .opium, photoFilter: .noir,
        noteColor: .pink, sticker: .bolt, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFF1A1A), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .embers, palette: .opium)),
        photos: library("Gothic", "Smoke", "Concert Lights"),
        kit: [
            KitItem(.wordArt, .large, 0, 0, Kit.wordArt("vamp", .fire, style: .gothic)),
            KitItem(.photo, .medium, 2, 0, Kit.photo(0)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.clock, .small, 5, 0),
            KitItem(.visualizer, .medium, 2, 1, Kit.visualizer(.ring)),
            KitItem(.photo, .medium, 4, 1, Kit.photo(5)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(2)),
            KitItem(.ticket, .medium, 2, 2, Kit.ticket("MOSH PIT", "Doors at midnight", venue: "The Crypt",
                                                        seat: "GA · PIT", inDays: 8, stripe: 0x8B0000)),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.quote, .medium, 0, 3, Kit.words("live fast,\nstay loud", style: .gothic)),
            KitItem(.photo, .medium, 2, 3, Kit.photo(11)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.battery, .small, 5, 3),
        ])

    /// Blond summer: cream and orange, sunflowers, a record and a slow drive.
    public static let blondSummer = WidgetTheme(
        id: "blondSummer", title: "Blond Summer", tagline: "Cream and orange: sunflowers, a record and a slow summer drive.",
        material: .paper, card: WidgetColor(hex: 0xFFF8EE), ink: WidgetColor(hex: 0x3A2A1A), accent: WidgetColor(hex: 0xF28C28),
        wallpaperInk: WidgetColor(hex: 0x3A2A1A), wallpaperAccent: WidgetColor(hex: 0xE35D1C),
        font: .standard, cornerRadius: 20, textStyle: .editorial, clockFace: .minimal, palette: .blond, photoFilter: .warm,
        noteColor: .yellow, sticker: .flower, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xF28C28), iconSymbol: "sun.max.fill",
        wallpaper: .art(ArtPiece(style: .blobs, palette: .blond)),
        photos: library("Sunflowers", "Night Drive", "Palm Sunsets"),
        kit: [
            KitItem(.polaroids, .large, 0, 0, Kit.prints(from: 0)),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("blond summer", .fire, style: .modern)),
            KitItem(.clock, .medium, 4, 0, Kit.bare),
            KitItem(.vinyl, .medium, 2, 1),
            KitItem(.photo, .medium, 4, 1, Kit.photo(1)),
            KitItem(.cassette, .medium, 0, 2, Kit.label("summer tape")),
            KitItem(.visualizer, .medium, 2, 2, Kit.visualizer(.mirror)),
            KitItem(.photo, .small, 4, 2, Kit.photo(6)),
            KitItem(.sticker, .small, 5, 2),
            KitItem(.quote, .medium, 0, 3, Kit.words("summer won't\nwait for you.", style: .editorial)),
            KitItem(.nowPlaying, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.weather, .small, 5, 3),
        ])
}

extension Kit {
    static func player(_ name: String, _ number: Int, kit preset: String, tagline: String = "", rating: Int? = nil,
                       finish: CardFinish? = nil, stats: [Int]? = nil) -> Configure {
        { widget, _ in
            widget.options.player.name = name
            widget.options.player.number = number
            widget.options.player.tagline = tagline
            if let kit = KitPreset.all.first(where: { $0.title == preset }) { widget.options.player.apply(kit) }
            if let rating { widget.options.player.rating = rating }
            if let finish { widget.options.player.finish = finish }
            if let stats, stats.count == 6 { widget.options.player.stats = stats }
        }
    }

    /// A match: counting down `inDays` from when the theme is applied, or a final score.
    static func match(_ home: String, _ away: String, _ homeColor: Int, _ awayColor: Int, _ competition: String,
                      inDays: Double? = nil, score: (Int, Int)? = nil, formation: Formation = .f433) -> Configure {
        { widget, _ in
            widget.options.match.home = home
            widget.options.match.away = away
            widget.options.match.homeColor = WidgetColor(hex: homeColor)
            widget.options.match.awayColor = WidgetColor(hex: awayColor)
            widget.options.match.competition = competition
            widget.options.match.formation = formation
            widget.options.match.kickoff = inDays.map { Calendar.current.startOfDay(for: .now).addingTimeInterval($0 * 86_400 + 20 * 3600) }
            widget.options.match.homeScore = score?.0
            widget.options.match.awayScore = score?.1
        }
    }

    static func ticket(_ headline: String, _ subtitle: String, venue: String, seat: String, inDays: Int, stripe: Int) -> Configure {
        { widget, _ in
            widget.options.ticket.headline = headline
            widget.options.ticket.subtitle = subtitle
            widget.options.ticket.venue = venue
            widget.options.ticket.seat = seat
            widget.options.ticket.date = Calendar.current.date(byAdding: .day, value: inDays, to: Calendar.current.startOfDay(for: .now))?
                .addingTimeInterval(20 * 3600)
            widget.tint = WidgetColor(hex: stripe)
        }
    }

    static func wordArt(_ text: String, _ finish: WordArtFinish, style: TextStyle? = nil, color: Int? = nil) -> Configure {
        { widget, _ in
            widget.options.customText = text
            widget.options.wordArt = finish
            if let style { widget.options.textStyle = style }
            if let color { widget.tint = WidgetColor(hex: color) }
        }
    }

    static func milestone(_ value: Int, _ suffix: String, _ label: String, _ caption: String) -> Configure {
        { widget, _ in
            widget.options.milestone.value = value
            widget.options.milestone.suffix = suffix
            widget.options.milestone.label = label
            widget.options.milestone.caption = caption
        }
    }

    static func visualizer(_ style: VisualizerStyle) -> Configure {
        { widget, _ in widget.options.visualizer = style }
    }

    /// The cassette's label while nothing plays.
    static func label(_ text: String) -> Configure {
        { widget, _ in widget.options.customText = text }
    }

    /// A photo from the theme on a VHS tape, with its caption.
    static func tape(_ index: Int, caption: String) -> Configure {
        { widget, theme in
            widget.options.images = [theme.photo(index)]
            widget.options.caption = caption
        }
    }

    static func note(_ text: String) -> Configure {
        { widget, _ in widget.options.noteText = text }
    }
}
