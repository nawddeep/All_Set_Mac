import Foundation

/// Photo-led desktops in the style people share: black-and-white photo walls,
/// script words, bold stickers and textured wallpapers, packed edge to edge.
/// Every photo is from the free library; every word and texture is original.
extension WidgetTheme {
    public static let moodboards: [WidgetTheme] = [
        leopardNoir, cityNoir, angelic, hypnotic, afterDark, streetwear, gallery, silverFaith,
        peaceOfMind, cherryNight, stardust, softMono, bohoSand, beginning,
    ]

    private static func photos(_ names: String...) -> [WebPhoto] { names.flatMap(CuratedBackgrounds.collection) }

    private static func backdrop(_ collection: String, _ index: Int) -> WallpaperSource {
        let photos = CuratedBackgrounds.collection(collection)
        return .photo(.web(photos.isEmpty ? CuratedBackgrounds.suggestion(0) : photos[index % photos.count]))
    }

    /// Leopard print, black-and-white glamour and a script word.
    public static let leopardNoir = WidgetTheme(
        id: "leopardNoir", title: "Leopard Noir", tagline: "Leopard print, old-Hollywood photos and a script signature.",
        material: .dark, card: WidgetColor(hex: 0x100D0B), ink: WidgetColor(hex: 0xF3ECE4), accent: WidgetColor(hex: 0xD9B38C),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xF1D9BD),
        font: .serif, cornerRadius: 14, textStyle: .script, clockFace: .digital, palette: .mocha, photoFilter: .noir,
        noteColor: .yellow, sticker: .crown, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE9E4DC), iconSymbol: "crown.fill",
        wallpaper: .art(ArtPiece(style: .leopard, palette: .mocha)),
        photos: photos("Portraits & Pets", "City Lights"),
        kit: [
            KitItem(.clock, .medium, 0, 0, Kit.bare),
            KitItem(.photo, .small, 2, 0, Kit.photo(0)),
            KitItem(.photo, .large, 3, 0, Kit.photo(1)),
            KitItem(.photo, .small, 5, 0, Kit.photo(2)),
            KitItem(.nowPlaying, .medium, 0, 1),
            KitItem(.quote, .small, 2, 1, Kit.words("Diva")),
            KitItem(.photo, .small, 5, 1, Kit.photo(3)),
            KitItem(.calendar, .medium, 0, 2),
            KitItem(.photo, .large, 2, 2, Kit.photo(4)),
            KitItem(.photo, .medium, 4, 2, Kit.photo(10)),
            KitItem(.photo, .small, 0, 3, Kit.photo(11)),
            KitItem(.sticker, .small, 1, 3),
            KitItem(.quote, .medium, 4, 3, Kit.both(Kit.words("HOLLYWOOD", style: .poster), Kit.light)),
        ])

    /// A black-and-white skyline with a few quiet glass tiles above it.
    public static let cityNoir = WidgetTheme(
        id: "cityNoir", title: "City Noir", tagline: "A night skyline in black and white, a few quiet tiles above it.",
        material: .dark, card: WidgetColor(hex: 0x1A1A1C), ink: WidgetColor(hex: 0xF5F5F5), accent: WidgetColor(hex: 0xFFFFFF),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .standard, cornerRadius: 16, textStyle: .modern, clockFace: .stacked, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .moon, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "building.2.fill",
        wallpaper: backdrop("City Lights", 1),
        photos: photos("City Lights", "Night & Stars"),
        kit: [
            KitItem(.photo, .medium, 2, 0, Kit.photo(3)),
            KitItem(.photo, .small, 4, 0, Kit.photo(5)),
            KitItem(.clock, .small, 5, 0),
            KitItem(.nowPlaying, .medium, 1, 1),
            KitItem(.battery, .small, 3, 1),
            KitItem(.date, .small, 4, 1),
            KitItem(.shortcuts, .small, 5, 1),
        ])

    /// Lace-white wallpaper, black tiles, script and a monogram.
    public static let angelic = WidgetTheme(
        id: "angelic", title: "Angelic", tagline: "Soft white, black tiles, a script word and a monogram.",
        material: .dark, card: WidgetColor(hex: 0x0B0B0B), ink: WidgetColor(hex: 0xF7F7F7), accent: WidgetColor(hex: 0xFFFFFF),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .serif, cornerRadius: 12, textStyle: .script, clockFace: .words, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .heart, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xEDEDED), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .clouds, palette: .mono)),
        photos: photos("Portraits & Pets", "Soft & Dreamy"),
        kit: [
            KitItem(.photo, .small, 0, 0, Kit.photo(0)),
            KitItem(.sticker, .small, 1, 0),
            KitItem(.photo, .small, 2, 0, Kit.photo(1)),
            KitItem(.photo, .medium, 4, 0, Kit.photo(2)),
            KitItem(.clock, .medium, 0, 1, { widget, _ in widget.options.clockFace = .digital }),
            KitItem(.quote, .medium, 2, 1, Kit.words("Angelic")),
            KitItem(.quote, .small, 4, 1, Kit.words("M")),
            KitItem(.photo, .small, 5, 1, Kit.photo(3)),
            KitItem(.photo, .large, 0, 2, Kit.photo(4)),
            KitItem(.weather, .small, 2, 2),
            KitItem(.calendar, .small, 3, 2),
        ])

    /// A big flip clock, a hypnotic spiral and a wall of monochrome film stills.
    public static let hypnotic = WidgetTheme(
        id: "hypnotic", title: "Hypnotic", tagline: "Flip clock, a spiral and a wall of monochrome stills.",
        material: .dark, card: WidgetColor(hex: 0x141414), ink: WidgetColor(hex: 0xF2F2F2), accent: WidgetColor(hex: 0xFFFFFF),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .standard, cornerRadius: 14, textStyle: .bold, clockFace: .flip, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .spiral, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xF2F2F2), iconSymbol: "circle.circle",
        wallpaper: .art(ArtPiece(style: .film, palette: .mono)),
        photos: photos("Portraits & Pets", "Mist & Forest", "City Lights"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.sticker, .small, 2, 0),
            KitItem(.photo, .small, 3, 0, Kit.photo(0)),
            KitItem(.nowPlaying, .medium, 4, 0),
            KitItem(.photo, .medium, 0, 1, Kit.photo(1)),
            KitItem(.photo, .large, 2, 1, Kit.photo(2)),
            KitItem(.photo, .small, 4, 1, Kit.photo(3)),
            KitItem(.quote, .small, 5, 1, Kit.both(Kit.words("form follows feeling", style: .editorial), Kit.light)),
            KitItem(.calendar, .medium, 0, 2),
            KitItem(.photo, .medium, 4, 2, Kit.photo(5)),
            KitItem(.weather, .medium, 0, 3),
            KitItem(.photo, .small, 2, 3, Kit.photo(12)),
            KitItem(.photo, .small, 3, 3, Kit.photo(13)),
        ])

    /// Dark grunge collage: a loud sticker word, gothic letters, smoky photos.
    public static let afterDark = WidgetTheme(
        id: "afterDark", title: "After Dark", tagline: "Smoky collage, a loud sticker word and gothic letters.",
        material: .dark, card: WidgetColor(hex: 0x0E0E0E), ink: WidgetColor(hex: 0xE8E2D6), accent: WidgetColor(hex: 0xE8E2D6),
        wallpaperInk: WidgetColor(hex: 0xEDE6D8), wallpaperAccent: WidgetColor(hex: 0xEDE6D8),
        font: .serif, cornerRadius: 10, textStyle: .gothic, clockFace: .digital, palette: .shadow, photoFilter: .noir,
        noteColor: .yellow, sticker: .flame, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xDADADA), iconSymbol: "flame.fill",
        wallpaper: .art(ArtPiece(style: .film, palette: .shadow)),
        photos: photos("City Lights", "Portraits & Pets", "Night & Stars"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.photo, .small, 2, 0, Kit.photo(0)),
            KitItem(.quote, .small, 3, 0, Kit.both(Kit.words("#SWAG", style: .poster), Kit.light)),
            KitItem(.photo, .large, 4, 0, Kit.photo(1)),
            KitItem(.nowPlaying, .medium, 0, 1),
            KitItem(.photo, .medium, 2, 1, Kit.photo(10)),
            KitItem(.photo, .medium, 0, 2, Kit.photo(11)),
            KitItem(.quote, .medium, 2, 2, Kit.words("Midnight Club", bare: true)),
            KitItem(.calendar, .small, 4, 2),
            KitItem(.dots, .small, 5, 2),
            KitItem(.photo, .medium, 0, 3, Kit.photo(12)),
            KitItem(.sticker, .small, 2, 3),
            KitItem(.photo, .medium, 3, 3, Kit.photo(14)),
        ])

    /// Topographic lines, white streetwear tiles and bold lowercase type.
    public static let streetwear = WidgetTheme(
        id: "streetwear", title: "Streetwear", tagline: "Contour lines, white tiles and bold lowercase type.",
        material: .light, card: WidgetColor(hex: 0xF4F4F2), ink: WidgetColor(hex: 0x0D0D0D), accent: WidgetColor(hex: 0x0D0D0D),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .standard, cornerRadius: 12, textStyle: .poster, clockFace: .flip, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .smiley, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .waves, palette: .mono)),
        photos: photos("City Lights", "Portraits & Pets"),
        kit: [
            KitItem(.quote, .small, 0, 0, Kit.words("blend.")),
            KitItem(.nowPlaying, .medium, 2, 0),
            KitItem(.photo, .small, 4, 0, Kit.photo(0)),
            KitItem(.photo, .small, 0, 1, Kit.photo(1)),
            KitItem(.quote, .medium, 1, 1, Kit.words("Stay close to people who feel like sunlight.", style: .editorial, kicker: "WORDS OF THE DAY")),
            KitItem(.vinyl, .small, 3, 1),
            KitItem(.photo, .large, 4, 1, Kit.photo(2)),
            KitItem(.photo, .small, 0, 2, Kit.photo(3)),
            KitItem(.clock, .medium, 1, 2, Kit.bare),
        ])

    /// Monochrome architecture and product shots, captioned like a zine.
    public static let gallery = WidgetTheme(
        id: "gallery", title: "Gallery", tagline: "Concrete, glass and vinyl, captioned like a zine.",
        material: .dark, card: WidgetColor(hex: 0x1B1B1B), ink: WidgetColor(hex: 0xF0F0F0), accent: WidgetColor(hex: 0xF0F0F0),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .standard, cornerRadius: 18, textStyle: .poster, clockFace: .minimal, palette: .mono, photoFilter: .mono,
        noteColor: .yellow, sticker: .music, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "square.fill",
        wallpaper: backdrop("City Lights", 2),
        photos: photos("City Lights", "Mist & Forest"),
        kit: [
            KitItem(.photo, .large, 0, 0, Kit.photo(0)),
            KitItem(.photo, .small, 2, 0, Kit.photo(1)),
            KitItem(.photo, .small, 3, 0, Kit.photo(2)),
            KitItem(.quote, .medium, 4, 0, Kit.words("ROOM NO.2", bare: true)),
            KitItem(.quote, .medium, 2, 1, Kit.words("The mediator between head and hands must be the heart.", style: .editorial)),
            KitItem(.clock, .small, 4, 1, Kit.bare),
            KitItem(.quote, .medium, 0, 2, Kit.words("THE GOOD PLACE")),
            KitItem(.vinyl, .medium, 2, 2),
        ])

    /// Pure black, chrome ornaments and one line of faith.
    public static let silverFaith = WidgetTheme(
        id: "silverFaith", title: "Silver Faith", tagline: "Pure black, chrome ornaments and one line of faith.",
        material: .dark, card: WidgetColor(hex: 0x0A0A0A), ink: WidgetColor(hex: 0xEFEFEF), accent: WidgetColor(hex: 0xC7C7C7),
        wallpaperInk: WidgetColor(hex: 0xEFEFEF), wallpaperAccent: WidgetColor(hex: 0xC7C7C7),
        font: .serif, cornerRadius: 6, textStyle: .luxe, clockFace: .minimal, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .star, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xE4E4E4), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .stars, palette: .mono)),
        photos: photos("Portraits & Pets", "Night & Stars"),
        kit: [
            KitItem(.clock, .medium, 0, 0, Kit.bare),
            KitItem(.sticker, .large, 0, 1),
            KitItem(.photo, .small, 2, 1, Kit.photo(0)),
            KitItem(.photo, .small, 3, 1, Kit.photo(1)),
            KitItem(.quote, .small, 4, 1, Kit.both(Kit.words("MY FUTURE IS IN GOD'S HANDS", style: .poster), Kit.light)),
            KitItem(.photo, .medium, 2, 2, Kit.photo(2)),
            KitItem(.date, .small, 4, 2, Kit.bare),
        ])

    /// A script blessing over the night, glass tiles and soft portraits.
    public static let peaceOfMind = WidgetTheme(
        id: "peaceOfMind", title: "Peace of Mind", tagline: "A script blessing, night glass and soft portraits.",
        material: .glass, card: WidgetColor(hex: 0x121212), ink: WidgetColor(hex: 0xF5F5F5), accent: WidgetColor(hex: 0x7CE08A),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .standard, cornerRadius: 18, textStyle: .script, clockFace: .digital, palette: .midnight, photoFilter: .noir,
        noteColor: .yellow, sticker: .sparkles, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "moon.fill",
        wallpaper: .art(ArtPiece(style: .stars, palette: .shadow)),
        photos: photos("Portraits & Pets", "City Lights"),
        kit: [
            KitItem(.quote, .medium, 0, 0, Kit.words("Bismillah", bare: true)),
            KitItem(.sticker, .small, 2, 0),
            KitItem(.photo, .small, 4, 0, Kit.photo(0)),
            KitItem(.clock, .small, 0, 1),
            KitItem(.battery, .small, 1, 1),
            KitItem(.photo, .large, 2, 1, Kit.photo(1)),
            KitItem(.nowPlaying, .medium, 4, 1),
            KitItem(.photo, .medium, 0, 2, Kit.photo(2)),
            KitItem(.photo, .small, 4, 2, Kit.photo(10)),
            KitItem(.quote, .small, 5, 2, Kit.words("Peace of mind", bare: true)),
        ])

    /// Dark red petals, glass tiles and warm film photos.
    public static let cherryNight = WidgetTheme(
        id: "cherryNight", title: "Cherry Night", tagline: "Dark red petals, glass tiles and warm film photos.",
        material: .glass, card: WidgetColor(hex: 0x1C0609), ink: WidgetColor(hex: 0xF7E7E9), accent: WidgetColor(hex: 0xE0314B),
        wallpaperInk: WidgetColor(hex: 0xFBE9EC), wallpaperAccent: WidgetColor(hex: 0xFF5A6E),
        font: .serif, cornerRadius: 16, textStyle: .elegant, clockFace: .analog, palette: .cherry, photoFilter: .vintage,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xC1121F), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .lava, palette: .cherry)),
        photos: photos("Portraits & Pets", "Golden Hour"),
        kit: [
            KitItem(.photo, .small, 0, 0, Kit.photo(0)),
            KitItem(.photo, .small, 1, 0, Kit.photo(1)),
            KitItem(.clock, .small, 2, 0),
            KitItem(.weather, .medium, 4, 0),
            KitItem(.photo, .large, 0, 1, Kit.photo(2)),
            KitItem(.photo, .medium, 2, 1, Kit.photo(3)),
            KitItem(.todo, .medium, 4, 1, Kit.list("tonight")),
            KitItem(.quote, .medium, 2, 2, Kit.words("cherry on top", style: .script, bare: true)),
            KitItem(.sticker, .small, 4, 2),
        ])

    /// Black sky, a burst of light, white tiles and wings.
    public static let stardust = WidgetTheme(
        id: "stardust", title: "Stardust", tagline: "Black sky, a burst of light and white paper tiles.",
        material: .clear, card: WidgetColor(hex: 0xF8F8F8), ink: WidgetColor(hex: 0x111111), accent: WidgetColor(hex: 0x111111),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .serif, cornerRadius: 16, textStyle: .elegant, clockFace: .minimal, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .sparkles, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "sparkles",
        wallpaper: .art(ArtPiece(style: .stars, palette: .mono)),
        photos: photos("Night & Stars", "Soft & Dreamy", "Portraits & Pets"),
        kit: [
            KitItem(.photo, .small, 0, 0, Kit.photo(5)),
            KitItem(.photo, .medium, 1, 0, Kit.photo(0)),
            KitItem(.photo, .small, 3, 0, Kit.photo(1)),
            KitItem(.vinyl, .medium, 4, 0),
            KitItem(.calendar, .medium, 0, 1),
            KitItem(.sticker, .large, 2, 1),
            KitItem(.todo, .small, 4, 1, Kit.both(Kit.list("Things to do"), Kit.light)),
            KitItem(.sticker, .small, 5, 2),
            KitItem(.photo, .medium, 0, 2, Kit.photo(2)),
        ])

    /// Light gray, mixed black and white tiles, fine handwriting.
    public static let softMono = WidgetTheme(
        id: "softMono", title: "Soft Mono", tagline: "Light gray, mixed black and white tiles, fine handwriting.",
        material: .light, card: WidgetColor(hex: 0xF3F3F1), ink: WidgetColor(hex: 0x1A1A1A), accent: WidgetColor(hex: 0x34C759),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .serif, cornerRadius: 18, textStyle: .handwritten, clockFace: .analog, palette: .mono, photoFilter: .mono,
        noteColor: .yellow, sticker: .flower, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0x1A1A1A), iconSymbol: "leaf.fill",
        wallpaper: .art(ArtPiece(style: .blobs, palette: .mono)),
        photos: photos("Soft & Dreamy", "City Lights"),
        kit: [
            KitItem(.battery, .small, 0, 0, Kit.dark),
            KitItem(.quote, .small, 1, 0, Kit.words("N", style: .script)),
            KitItem(.photo, .small, 2, 0, Kit.photo(0)),
            KitItem(.quote, .small, 0, 1, Kit.words("grateful for small things, big change and everything in between")),
            KitItem(.photo, .medium, 1, 1, Kit.photo(1)),
            KitItem(.nowPlaying, .medium, 0, 2, Kit.dark),
            KitItem(.clock, .small, 2, 2),
            KitItem(.calendar, .small, 0, 3, Kit.dark),
            KitItem(.clock, .medium, 1, 3, Kit.both({ widget, _ in widget.options.clockFace = .stacked }, Kit.bare)),
        ])

    /// Sand and cream, line-drawn flowers and handwriting.
    public static let bohoSand = WidgetTheme(
        id: "bohoSand", title: "Boho Sand", tagline: "Sand and cream, line-drawn flowers and handwriting.",
        material: .paper, card: WidgetColor(hex: 0xEFE6DA), ink: WidgetColor(hex: 0x4A3F35), accent: WidgetColor(hex: 0x8C7B6B),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .serif, cornerRadius: 22, textStyle: .handwritten, clockFace: .minimal, palette: .mocha, photoFilter: .fade,
        noteColor: .yellow, sticker: .flower, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "leaf.fill",
        wallpaper: .art(ArtPiece(style: .blobs, palette: .mocha)),
        photos: photos("Soft & Dreamy", "Mist & Forest"),
        kit: [
            KitItem(.clock, .medium, 0, 0, Kit.bare),
            KitItem(.photo, .small, 2, 0, Kit.photo(0)),
            KitItem(.quote, .small, 3, 0, Kit.both(Kit.words("smile", style: .script), Kit.dark)),
            KitItem(.sticker, .small, 0, 1),
            KitItem(.quote, .medium, 1, 1, Kit.words("good things take time")),
            KitItem(.calendar, .small, 3, 1),
            KitItem(.photo, .medium, 0, 2, Kit.photo(1)),
            KitItem(.todo, .medium, 2, 2),
        ])

    /// Molten ink wallpaper with clean, bare widgets over it.
    public static let beginning = WidgetTheme(
        id: "beginning", title: "The Beginning", tagline: "Molten ink behind clean, bare widgets.",
        material: .clear, card: WidgetColor(hex: 0x0C0C0C), ink: WidgetColor(hex: 0xF5F0EA), accent: WidgetColor(hex: 0xF2A65A),
        wallpaperInk: WidgetColor(hex: 0xF5F0EA), wallpaperAccent: WidgetColor(hex: 0xF2A65A),
        font: .standard, cornerRadius: 14, textStyle: .poster, clockFace: .stacked, palette: .ember, photoFilter: .none,
        noteColor: .yellow, sticker: .bolt, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xF2A65A), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .lava, palette: .ember)),
        photos: photos("Desert"),
        kit: [
            KitItem(.calendar, .medium, 0, 0),
            KitItem(.quote, .medium, 2, 0, Kit.words("THE BEGINNING")),
            KitItem(.system, .medium, 4, 0),
            KitItem(.todo, .medium, 0, 1),
            KitItem(.clock, .medium, 2, 1),
            KitItem(.nowPlaying, .medium, 4, 1),
            KitItem(.weather, .medium, 0, 2),
        ])
}

extension Kit {
    /// A white paper tile with black ink, like a printed sticker.
    static let light: Configure = { widget, _ in
        widget.material = .paper
        widget.tint = WidgetColor(hex: 0xF4F2EE)
        widget.options.ink = WidgetColor(hex: 0x111111)
        widget.options.accent = WidgetColor(hex: 0x111111)
    }

    /// A black tile with white ink.
    static let dark: Configure = { widget, _ in
        widget.material = .dark
        widget.tint = WidgetColor(hex: 0x111111)
        widget.options.ink = WidgetColor(hex: 0xF5F5F5)
        widget.options.accent = WidgetColor(hex: 0xF5F5F5)
    }

    static func both(_ first: @escaping Configure, _ second: @escaping Configure) -> Configure {
        { widget, theme in
            first(&widget, theme)
            second(&widget, theme)
        }
    }
}
