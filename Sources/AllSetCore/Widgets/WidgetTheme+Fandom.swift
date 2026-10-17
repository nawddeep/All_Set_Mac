import Foundation

/// Football and music worlds: whole desktops built on moods (floodlit nights,
/// rainy derbies, late-night drives), packed edge to edge with the new live
/// widgets. Every player, club, fixture and venue is invented; none points at a
/// real person, club, nation, kit, crest, album or lyric (`RealPeopleDenylistTests`).
/// Photos are CC0 places and things; the words are our own. The `id`s are old
/// names kept only so saved desktops still decode; they are never shown.
extension WidgetTheme {
    public static let fandom: [WidgetTheme] = [
        floodlightGold, rainDerby, ivoryCrown, skyPlaymaker, goldenAge, neonFlair, wonderkid, midnightSprint, emberTerrace, legends, palmNightPink, matchday,
        americana, coastline, violetNoir, emberCrowd, rainHours, acidMoss, deepBlue, crimsonNights, gothicStatic, sunflowerDrive,
    ]

    static func library(_ names: String...) -> [WebPhoto] { names.flatMap(CuratedBackgrounds.collection) }

    static func backdropPhoto(_ collection: String, _ index: Int) -> WallpaperSource {
        let photos = CuratedBackgrounds.collection(collection)
        return .photo(.web(photos.isEmpty ? CuratedBackgrounds.suggestion(0) : photos[index % photos.count]))
    }

    // MARK: Football

    /// Floodlit gold: deep red and pine green under the lights, gold on top.
    public static let floodlightGold = WidgetTheme(
        id: "floodlightGold", title: "Floodlight Gold", tagline: "Red, pine and gold under the floodlights. Dream big, work harder.",
        material: .dark, card: WidgetColor(hex: 0x0E0A0B), ink: WidgetColor(hex: 0xF4EDE4), accent: WidgetColor(hex: 0xE8C15A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xE8C15A),
        font: .condensed, cornerRadius: 16, textStyle: .poster, clockFace: .flip, palette: .redGreen, photoFilter: .none,
        noteColor: .yellow, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "soccerball",
        wallpaper: .art(ArtPiece(style: .stadium, palette: .redGreen)),
        photos: library("Stadium Nights", "On the Pitch", "Golden Goal"),
        kit: [
            KitItem(.jersey, .large, 0, 0, Kit.player("CAPTAIN", 14, kit: "Red & Green", tagline: "DREAM BIG")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Floodlight", .gold, style: .script)),
            KitItem(.clock, .small, 4, 0),
            KitItem(.photo, .small, 5, 0, Kit.photo(1)),
            KitItem(.playerCard, .large, 2, 1, Kit.player("CAPTAIN", 14, kit: "Red & Green", tagline: "WORK HARDER", rating: 94,
                                                            finish: .gold, stats: [90, 95, 82, 88, 35, 86])),
            KitItem(.milestone, .medium, 4, 1, Kit.milestone(250, "", "MATCHES", "and counting")),
            KitItem(.scoreboard, .medium, 0, 2, Kit.match("LIO", "FAL", 0xC8102E, 0xF1BF00, "FRIENDLY", inDays: 4)),
            KitItem(.photo, .medium, 4, 2, Kit.photo(2)),
            KitItem(.quote, .medium, 0, 3, Kit.words("Dream big.\nWork harder.", style: .poster)),
            KitItem(.focus, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.photo, .small, 5, 3, Kit.photo(8)),
        ])

    /// Ivory and gold: grand nights, trophies on black, fine serif.
    public static let ivoryCrown = WidgetTheme(
        id: "ivoryCrown", title: "Ivory Crown", tagline: "Ivory and gold, trophies on black, grand cup nights.",
        material: .light, card: WidgetColor(hex: 0xF6F3EC), ink: WidgetColor(hex: 0x1C2440), accent: WidgetColor(hex: 0xB8902F),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xE8C15A),
        font: .serif, cornerRadius: 18, textStyle: .luxe, clockFace: .minimal, palette: .royal, photoFilter: .none,
        noteColor: .yellow, sticker: .crown, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "crown.fill",
        wallpaper: backdropPhoto("Golden Goal", 4),
        photos: library("Golden Goal", "Stadium Nights"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Ivory Crown", .gold, style: .luxe)),
            KitItem(.jersey, .medium, 2, 0, Kit.player("MAESTRO", 5, kit: "Royal White", tagline: "IVORY & GOLD")),
            KitItem(.clock, .small, 4, 0, Kit.bare),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.playerCard, .large, 0, 1, Kit.player("MAESTRO", 5, kit: "Royal White", tagline: "GRAND NIGHTS", rating: 97,
                                                            finish: .legend, stats: [91, 95, 83, 89, 34, 85])),
            KitItem(.photo, .large, 2, 1, Kit.photo(5)),
            KitItem(.milestone, .small, 4, 1, Kit.both(Kit.milestone(3, "×", "CUP NIGHTS", ""), Kit.dark)),
            KitItem(.calendar, .small, 5, 1),
            KitItem(.ticket, .medium, 4, 2, Kit.ticket("CUP NIGHT", "Under the white lights", venue: "The Ivory Ground",
                                                        seat: "EAST · ROW 7", inDays: 12, stripe: 0xB8902F)),
            KitItem(.nowPlaying, .medium, 0, 3),
            KitItem(.quote, .medium, 2, 3, Kit.words("Class is permanent.", style: .luxe)),
            KitItem(.weather, .medium, 4, 3),
        ])

    /// A winger in red: rainy floodlit nights and step-overs.
    public static let rainDerby = WidgetTheme(
        id: "rainDerby", title: "Rain Derby", tagline: "A young winger in red: rainy floodlit nights and step-overs.",
        material: .dark, card: WidgetColor(hex: 0x120204), ink: WidgetColor(hex: 0xFFF3F0), accent: WidgetColor(hex: 0xD0021B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF3B3B),
        font: .condensed, cornerRadius: 16, textStyle: .poster, clockFace: .flip, palette: .classicRed, photoFilter: .none,
        noteColor: .pink, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "cloud.rain.fill",
        wallpaper: .art(ArtPiece(style: .rain, palette: .classicRed)),
        photos: library("Stadium Nights", "On the Pitch"),
        kit: [
            KitItem(.photo, .large, 0, 0, Kit.photo(0)),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("No. 17", .chrome, style: .poster)),
            KitItem(.clock, .medium, 4, 0),
            KitItem(.playerCard, .large, 2, 1, Kit.player("THE WINGER", 17, kit: "Classic Red", tagline: "RAINY NIGHT RUNS", rating: 91,
                                                            finish: .gold, stats: [93, 87, 78, 91, 32, 75])),
            KitItem(.jersey, .medium, 4, 1, Kit.player("WINGER", 17, kit: "Classic Red", tagline: "STEP-OVERS")),
            KitItem(.photo, .medium, 0, 2, Kit.photo(1)),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(60, "", "ASSISTS", "this season")),
            KitItem(.photo, .small, 0, 3, Kit.photo(2)),
            KitItem(.photo, .small, 1, 3, Kit.photo(3)),
            KitItem(.scoreboard, .medium, 2, 3, Kit.match("HAR", "CAS", 0xD0021B, 0x034694, "CUP FINAL", score: (1, 1))),
            KitItem(.nowPlaying, .medium, 4, 3),
        ])

    /// The boy wonder: violet and gold, stadium bokeh and the number sixteen.
    public static let wonderkid = WidgetTheme(
        id: "wonderkid", title: "Wonderkid", tagline: "Violet and gold, stadium bokeh and a teenager changing the game.",
        material: .frosted, card: WidgetColor(hex: 0x0B0E2A), ink: WidgetColor(hex: 0xFFFFFF), accent: WidgetColor(hex: 0xEDBB00),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFD54A),
        font: .rounded, cornerRadius: 22, textStyle: .bold, clockFace: .digital, palette: .violetGold, photoFilter: .none,
        noteColor: .blue, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xEDBB00), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .bokeh, palette: .violetGold)),
        photos: library("On the Pitch", "Stadium Nights"),
        kit: [
            KitItem(.playerCard, .large, 0, 0, Kit.player("WONDERKID", 16, kit: "Midnight", tagline: "BORN FOR THIS", rating: 90,
                                                            finish: .holo, stats: [90, 82, 86, 92, 30, 60])),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Wonderkid", .holo, style: .bold)),
            KitItem(.jersey, .small, 4, 0, Kit.player("WONDERKID", 16, kit: "Midnight")),
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

    /// A city at night in navy and gold: speed and royal blue.
    public static let midnightSprint = WidgetTheme(
        id: "midnightSprint", title: "Midnight Sprint", tagline: "A city at night in navy and gold: pure speed on the counter.",
        material: .glass, card: WidgetColor(hex: 0x0C1A3F), ink: WidgetColor(hex: 0xFFFFFF), accent: WidgetColor(hex: 0xE8C15A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xF3D36B),
        font: .expanded, cornerRadius: 18, textStyle: .modern, clockFace: .stacked, palette: .bleu, photoFilter: .none,
        noteColor: .blue, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .skyline, palette: .bleu)),
        photos: library("Stadium Nights", "On the Pitch"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Midnight Sprint", .gold, style: .modern)),
            KitItem(.clock, .medium, 2, 0),
            KitItem(.jersey, .medium, 4, 0, Kit.player("VITESSE", 21, kit: "Navy Bleu", tagline: "SPEED IS POWER")),
            KitItem(.photo, .large, 0, 1, Kit.photo(0)),
            KitItem(.playerCard, .large, 2, 1, Kit.player("VITESSE", 21, kit: "Navy Bleu", tagline: "CITY NIGHTS", rating: 92,
                                                            finish: .night, stats: [97, 90, 80, 92, 36, 77])),
            KitItem(.scoreboard, .medium, 4, 1, Kit.match("NAV", "SKY", 0x1C2A5A, 0x75AADB, "KNOCKOUT ROUND", score: (4, 3))),
            KitItem(.photo, .medium, 4, 2, Kit.photo(1)),
            KitItem(.quote, .medium, 0, 3, Kit.words("Fast. Fearless.\nFree.", style: .modern)),
            KitItem(.nowPlaying, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.weather, .small, 5, 3),
        ])

    /// Ember red and charcoal, flares in the stands and pure elegance.
    public static let emberTerrace = WidgetTheme(
        id: "emberTerrace", title: "Ember Terrace", tagline: "Ember red and charcoal, flares in the stands and pure elegance.",
        material: .dark, card: WidgetColor(hex: 0x0C0606), ink: WidgetColor(hex: 0xF8EEEE), accent: WidgetColor(hex: 0xC8102E),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF5A4A),
        font: .serif, cornerRadius: 12, textStyle: .luxe, clockFace: .minimal, palette: .emberCharcoal, photoFilter: .none,
        noteColor: .pink, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .smoke, palette: .emberCharcoal)),
        photos: library("Stadium Nights", "Smoke"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Terrace", .gold, style: .luxe)),
            KitItem(.photo, .large, 2, 0, Kit.photo(0)),
            KitItem(.playerCard, .large, 4, 0, Kit.player("ELEGANZA", 22, kit: "Orange Hoops", tagline: "EMBER NIGHTS",
                                                            rating: 93, finish: .night, stats: [88, 86, 92, 93, 40, 76])),
            KitItem(.jersey, .medium, 0, 1, Kit.player("CAPTAIN", 4, kit: "Orange Hoops", tagline: "ONE CLUB, ONE LIFE")),
            KitItem(.photo, .large, 0, 2, Kit.photo(1)),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(2, caption: "THE OLD TERRACE")),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(100, "", "YEARS", "on the same terrace")),
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

    /// Sky and white, a playmaker and a little magic.
    public static let skyPlaymaker = WidgetTheme(
        id: "skyPlaymaker", title: "Sky Playmaker", tagline: "Sky and white, a playmaker's touch and a little magic.",
        material: .frosted, card: WidgetColor(hex: 0x0E1B2E), ink: WidgetColor(hex: 0xF2F7FC), accent: WidgetColor(hex: 0x75AADB),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x9CCBF0),
        font: .rounded, cornerRadius: 20, textStyle: .bold, clockFace: .digital, palette: .skyWhite, photoFilter: .none,
        noteColor: .blue, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE8C15A), iconSymbol: "star.fill",
        wallpaper: backdropPhoto("Stadium Nights", 0),
        photos: library("On the Pitch", "Stadium Nights", "Golden Goal"),
        kit: [
            KitItem(.jersey, .large, 0, 0, Kit.player("PLAYMAKER", 8, kit: "Black & White", tagline: "PURE MAGIC")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Playmaker", .gold, style: .poster)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.clock, .small, 5, 0),
            KitItem(.pitch, .medium, 2, 1, Kit.match("SKY", "NAV", 0x75AADB, 0x1F3A93, "FINAL", inDays: nil)),
            KitItem(.playerCard, .medium, 4, 1, Kit.player("PLAYMAKER", 8, kit: "Black & White", tagline: "LEFT FOOT MAGIC", rating: 96,
                                                             finish: .legend, stats: [85, 92, 94, 96, 38, 68])),
            KitItem(.photo, .medium, 0, 2, Kit.photo(0)),
            KitItem(.scoreboard, .medium, 2, 2, Kit.match("SKY", "NAV", 0x75AADB, 0x1F3A93, "FINAL", score: (3, 3))),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(300, "", "ASSISTS", "and still looking")),
            KitItem(.nowPlaying, .medium, 0, 3),
            KitItem(.calendar, .small, 2, 3),
            KitItem(.weather, .small, 3, 3),
            KitItem(.photo, .medium, 4, 3, Kit.photo(3)),
        ])

    /// A golden age in color: mustard, forest and cream, retro stripes, film.
    public static let goldenAge = WidgetTheme(
        id: "goldenAge", title: "Golden Age", tagline: "An old-school era: sunny yellow, retro stripes and film grain.",
        material: .paper, card: WidgetColor(hex: 0xF3E9D2), ink: WidgetColor(hex: 0x1F3B1F), accent: WidgetColor(hex: 0x009C3B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFDF00),
        font: .serif, cornerRadius: 10, textStyle: .chunky, clockFace: .analog, palette: .canary, photoFilter: .vintage,
        noteColor: .yellow, sticker: .crown, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xFFDF00), iconSymbol: "crown.fill",
        wallpaper: .art(ArtPiece(style: .stripes, palette: .canary)),
        photos: library("Golden Goal", "On the Pitch"),
        kit: [
            KitItem(.sticker, .small, 0, 0),
            KitItem(.wordArt, .medium, 1, 0, Kit.wordArt("Golden Age", .gold, style: .chunky)),
            KitItem(.scoreboard, .medium, 3, 0, Kit.match("SOL", "AZU", 0xFFD400, 0x1F5FBF, "FINAL · '71", score: (4, 1))),
            KitItem(.clock, .small, 5, 0),
            KitItem(.jersey, .large, 0, 1, Kit.player("SOLANO", 9, kit: "Forest Sash", tagline: "CLASS OF '71")),
            KitItem(.vhs, .large, 2, 1, Kit.tape(1, caption: "SUMMER OF '71")),
            KitItem(.playerCard, .medium, 4, 1, Kit.player("SOLANO", 9, kit: "Forest Sash", tagline: "OLD SCHOOL", rating: 98,
                                                             finish: .legend, stats: [93, 97, 90, 96, 50, 80])),
            KitItem(.milestone, .medium, 4, 2, Kit.milestone(500, "", "MATCHES", "one club, one era")),
            KitItem(.quote, .medium, 0, 3, Kit.words("The beautiful game.", style: .chunky)),
            KitItem(.calendar, .small, 2, 3),
            KitItem(.photo, .small, 3, 3, Kit.photo(2)),
            KitItem(.nowPlaying, .medium, 4, 3),
        ])

    /// Flair in neon: canary yellow on a synth grid, skills and samba.
    public static let neonFlair = WidgetTheme(
        id: "neonFlair", title: "Neon Flair", tagline: "Sunny yellow on a neon grid: skill, flair and street football.",
        material: .dark, card: WidgetColor(hex: 0x07100A), ink: WidgetColor(hex: 0xF5FFF0), accent: WidgetColor(hex: 0xFFDF00),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFE14D),
        font: .expanded, cornerRadius: 18, textStyle: .bold, clockFace: .digital, palette: .canary, photoFilter: .none,
        noteColor: .yellow, sticker: .bolt, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFDF00), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .synthwave, palette: .canary)),
        photos: library("On the Pitch", "Neon Green", "Concert Lights"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Flair", .neon, style: .script, color: 0xFFE14D)),
            KitItem(.playerCard, .large, 2, 0, Kit.player("FLAIR", 11, kit: "Canary", tagline: "SKILL IS A LANGUAGE", rating: 91,
                                                            finish: .neon, stats: [91, 85, 86, 94, 32, 62])),
            KitItem(.jersey, .small, 4, 0, Kit.player("FLAIR", 11, kit: "Canary")),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.visualizer, .medium, 0, 1, Kit.visualizer(.bars)),
            KitItem(.pitch, .medium, 4, 1, Kit.match("SOL", "SKY", 0xFFD400, 0x75AADB, "STREET CUP", inDays: 6)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(9)),
            KitItem(.photo, .medium, 2, 2, Kit.photo(4)),
            KitItem(.scoreboard, .medium, 4, 2, Kit.match("SOL", "SKY", 0xFFD400, 0x75AADB, "STREET CUP", inDays: 6)),
            KitItem(.clock, .medium, 0, 3, Kit.bare),
            KitItem(.focus, .medium, 2, 3),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.battery, .small, 5, 3),
        ])

    /// Pink and black by the ocean: palm silhouettes and a new chapter.
    public static let palmNightPink = WidgetTheme(
        id: "palmNightPink", title: "Palm Night Pink", tagline: "Pink and black, palms at night, a new chapter by the sea.",
        material: .dark, card: WidgetColor(hex: 0x0D0A0C), ink: WidgetColor(hex: 0xFFF0F6), accent: WidgetColor(hex: 0xF4A6C6),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF8FC2),
        font: .rounded, cornerRadius: 22, textStyle: .script, clockFace: .flip, palette: .miami, photoFilter: .none,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xF4A6C6), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .palms, palette: .miami)),
        photos: library("Palm Sunsets", "Neon Motels", "On the Pitch"),
        kit: [
            KitItem(.jersey, .medium, 0, 0, Kit.player("PALMS", 23, kit: "Pink & Black", tagline: "NEW CHAPTER")),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("Palm Nights", .neon, style: .script, color: 0xFF8FC2)),
            KitItem(.clock, .medium, 4, 0),
            KitItem(.playerCard, .large, 0, 1, Kit.player("PALMS", 23, kit: "Pink & Black", tagline: "PINK IS THE NEW GOLD", rating: 93,
                                                            finish: .neon, stats: [80, 90, 93, 94, 33, 64])),
            KitItem(.photo, .large, 2, 1, Kit.photo(0)),
            KitItem(.ticket, .medium, 4, 1, Kit.ticket("MATCH NIGHT", "Pink under the lights", venue: "The Seaside Ground",
                                                        seat: "SEC 110 · ROW 10", inDays: 9, stripe: 0xF4A6C6)),
            KitItem(.scoreboard, .medium, 4, 2, Kit.match("PAL", "HAR", 0xF4A6C6, 0x6CACE4, "SEASON", inDays: 5)),
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

}
