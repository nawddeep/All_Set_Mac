import Foundation

/// The music worlds (see `WidgetTheme.fandom`).
extension WidgetTheme {
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
            KitItem(.quote, .medium, 2, 3, Kit.words("Golden hour on the boulevard.", style: .typewriter)),
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

    /// Earth tones turned up: smoke, fire, a crowd in the dark.
    public static let emberCrowd = WidgetTheme(
        id: "emberCrowd", title: "Ember Crowd", tagline: "Smoke, fire and a crowd in the dark. Earth tones, turned all the way up.",
        material: .dark, card: WidgetColor(hex: 0x160E09), ink: WidgetColor(hex: 0xF3E6D4), accent: WidgetColor(hex: 0xE3B26B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF8A3D),
        font: .condensed, cornerRadius: 12, textStyle: .poster, clockFace: .flip, palette: .rage, photoFilter: .warm,
        noteColor: .yellow, sticker: .flame, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE3B26B), iconSymbol: "flame.fill",
        wallpaper: .art(ArtPiece(style: .smoke, palette: .rage)),
        photos: library("Desert Fire", "Concert Lights", "Smoke"),
        kit: [
            KitItem(.wordArt, .large, 0, 0, Kit.wordArt("TURN IT UP", .fire, style: .poster)),
            KitItem(.visualizer, .medium, 2, 0, Kit.visualizer(.bars)),
            KitItem(.photo, .medium, 4, 0, Kit.photo(9)),
            KitItem(.vhs, .medium, 2, 1, Kit.tape(10, caption: "LIVE · LOUD")),
            KitItem(.photo, .small, 4, 1, Kit.photo(0)),
            KitItem(.sticker, .small, 5, 1),
            KitItem(.photo, .medium, 0, 2, Kit.photo(4)),
            KitItem(.ticket, .medium, 2, 2, Kit.ticket("LOUD NIGHT", "Mosh pit, front row", venue: "The Dome",
                                                        seat: "GA · PIT", inDays: 11, stripe: 0xC46A2B)),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.clock, .medium, 0, 3),
            KitItem(.photo, .medium, 2, 3, Kit.photo(18)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.battery, .small, 5, 3),
        ])

    /// Blue hours: rain on the window, a 3 a.m. tape, soft handwriting.
    public static let rainHours = WidgetTheme(
        id: "rainHours", title: "Rain Hours", tagline: "Rain on the window, a 3 a.m. tape and soft handwriting in blue.",
        material: .glass, card: WidgetColor(hex: 0x0A1633), ink: WidgetColor(hex: 0xE8F0FF), accent: WidgetColor(hex: 0x8FB3FF),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x8FB3FF),
        font: .standard, cornerRadius: 18, textStyle: .handwritten, clockFace: .digital, palette: .sadBlue, photoFilter: .cool,
        noteColor: .blue, sticker: .heart, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0x8FB3FF), iconSymbol: "cloud.rain.fill",
        wallpaper: .art(ArtPiece(style: .rain, palette: .sadBlue)),
        photos: library("Rainy Window", "Night Drive"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("rain hours", .neon, style: .handwritten, color: 0x4D8BFF)),
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

    /// Black and acid moss green: quiet, weird and glowing.
    public static let acidMoss = WidgetTheme(
        id: "acidMoss", title: "Acid Moss", tagline: "Black and acid green: quiet, a little weird, glowing.",
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
            KitItem(.vhs, .medium, 2, 2, Kit.tape(8, caption: "LATE TAPES")),
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

    /// Red neon after midnight: a city in crimson, a night drive.
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
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("red light city", .neon, style: .modern, color: 0xFF2D3F)),
            KitItem(.clock, .medium, 4, 0),
            KitItem(.visualizer, .medium, 2, 1, Kit.visualizer(.bars)),
            KitItem(.photo, .small, 4, 1, Kit.photo(19)),
            KitItem(.photo, .small, 5, 1, Kit.photo(17)),
            KitItem(.ticket, .medium, 0, 2, Kit.ticket("LATE SHOW", "One night only", venue: "Neon Hall",
                                                        seat: "FLOOR · A1", inDays: 20, stripe: 0xE11D2A)),
            KitItem(.vhs, .medium, 2, 2, Kit.tape(3, caption: "3:00 AM")),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.cassette, .medium, 0, 3, Kit.label("night drive")),
            KitItem(.photo, .medium, 2, 3, Kit.photo(5)),
            KitItem(.calendar, .small, 4, 3),
            KitItem(.weather, .small, 5, 3),
        ])

    /// Gothic punk in black and red: blackletter, cathedrals, a mosh pit.
    public static let gothicStatic = WidgetTheme(
        id: "gothicStatic", title: "Gothic Static", tagline: "Black and blood red: blackletter, cathedrals and a mosh pit.",
        material: .dark, card: WidgetColor(hex: 0x050000), ink: WidgetColor(hex: 0xF2F2F2), accent: WidgetColor(hex: 0xFF1A1A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF2A2A),
        font: .standard, cornerRadius: 4, textStyle: .gothic, clockFace: .words, palette: .bloodRed, photoFilter: .noir,
        noteColor: .pink, sticker: .bolt, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFF1A1A), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .embers, palette: .bloodRed)),
        photos: library("Gothic", "Smoke", "Concert Lights"),
        kit: [
            KitItem(.wordArt, .large, 0, 0, Kit.wordArt("static", .fire, style: .gothic)),
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

    /// Sunflower drive: cream and orange, sunflowers, a record and a slow drive.
    public static let sunflowerDrive = WidgetTheme(
        id: "sunflowerDrive", title: "Sunflower Drive", tagline: "Cream and orange: sunflowers, a record and a slow summer drive.",
        material: .paper, card: WidgetColor(hex: 0xFFF8EE), ink: WidgetColor(hex: 0x3A2A1A), accent: WidgetColor(hex: 0xF28C28),
        wallpaperInk: WidgetColor(hex: 0x3A2A1A), wallpaperAccent: WidgetColor(hex: 0xE35D1C),
        font: .standard, cornerRadius: 20, textStyle: .editorial, clockFace: .minimal, palette: .blond, photoFilter: .warm,
        noteColor: .yellow, sticker: .flower, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xF28C28), iconSymbol: "sun.max.fill",
        wallpaper: .art(ArtPiece(style: .blobs, palette: .blond)),
        photos: library("Sunflowers", "Night Drive", "Palm Sunsets"),
        kit: [
            KitItem(.polaroids, .large, 0, 0, Kit.prints(from: 0)),
            KitItem(.wordArt, .medium, 2, 0, Kit.wordArt("sunflower drive", .fire, style: .modern)),
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
