import Foundation

/// Colour and light: bright, warm and pastel desktops, to sit beside the
/// black-and-white moodboards. Every word, palette and layout is original;
/// photos come from the free library.
extension WidgetTheme {
    public static let colour: [WidgetTheme] = [
        matchaMorning, peachFizz, lavenderHaze, candyPop, oceanGlass, sunsetDrive, forestCabin, desertBloom,
    ]

    private static func pool(_ names: String...) -> [WebPhoto] { names.flatMap(CuratedBackgrounds.collection) }

    // MARK: Light

    /// Sage and oat, slow mornings, handwriting.
    public static let matchaMorning = WidgetTheme(
        id: "matchaMorning", title: "Matcha Morning", tagline: "Sage and oat milk, slow mornings and soft handwriting.",
        material: .paper, card: WidgetColor(hex: 0xF4F1E6), ink: WidgetColor(hex: 0x3E4A36), accent: WidgetColor(hex: 0x5F7A48),
        wallpaperInk: WidgetColor(hex: 0x34402C), wallpaperAccent: WidgetColor(hex: 0x4F6A3C),
        font: .rounded, cornerRadius: 20, textStyle: .handwritten, clockFace: .minimal, palette: .matcha, photoFilter: .warm,
        noteColor: .green, sticker: .flower, stickerFinish: .soft, stickerColor: WidgetColor(hex: 0x9CAF88), iconSymbol: "leaf.fill",
        wallpaper: .art(ArtPiece(style: .blobs, palette: .matcha)),
        photos: pool("Mist & Forest", "Soft & Dreamy"),
        kit: [
            KitItem(.clock, .medium, 0, 0, Kit.bare),
            KitItem(.weather, .small, 2, 0),
            KitItem(.photo, .small, 3, 0, Kit.photo(0)),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.calendar, .small, 5, 0),
            KitItem(.quote, .large, 0, 1, Kit.words("slow mornings,\nsoft starts", style: .handwritten)),
            KitItem(.todo, .medium, 2, 1, Kit.list("today")),
            KitItem(.photo, .medium, 4, 1, Kit.photo(1)),
            KitItem(.focus, .medium, 2, 2),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.quote, .small, 0, 3, Kit.words("breathe", style: .script, bare: true)),
            KitItem(.photo, .small, 1, 3, Kit.photo(2)),
        ])

    /// Peach and coral, sunshine and big friendly type.
    public static let peachFizz = WidgetTheme(
        id: "peachFizz", title: "Peach Fizz", tagline: "Peach and coral, sunshine and big, friendly type.",
        material: .frosted, card: WidgetColor(hex: 0xFFF5EC), ink: WidgetColor(hex: 0x5A2A1E), accent: WidgetColor(hex: 0xC8452E),
        wallpaperInk: WidgetColor(hex: 0x5A2A1E), wallpaperAccent: WidgetColor(hex: 0xB33E28),
        font: .rounded, cornerRadius: 24, textStyle: .chunky, clockFace: .stacked, palette: .peach, photoFilter: .warm,
        noteColor: .pink, sticker: .smiley, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xFF9A76), iconSymbol: "sun.max.fill",
        wallpaper: .art(ArtPiece(style: .bokeh, palette: .peach)),
        photos: pool("Golden Hour", "Sunflowers"),
        kit: [
            KitItem(.quote, .medium, 0, 0, Kit.words("Make today fizz.", style: .chunky)),
            KitItem(.clock, .small, 2, 0),
            KitItem(.photo, .large, 3, 0, Kit.photo(0)),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.nowPlaying, .medium, 0, 1),
            KitItem(.stopwatch, .small, 2, 1),
            KitItem(.calendar, .small, 5, 1),
            KitItem(.photo, .small, 0, 2, Kit.photo(1)),
            KitItem(.todo, .medium, 1, 2),
            KitItem(.quote, .small, 3, 2, Kit.words("say yes", style: .script)),
            KitItem(.weather, .medium, 4, 2),
            KitItem(.dots, .medium, 0, 3),
            KitItem(.shortcuts, .medium, 2, 3, Kit.bare),
        ])

    /// Lilac clouds, frosted glass and a watch face.
    public static let lavenderHaze = WidgetTheme(
        id: "lavenderHaze", title: "Lavender Haze", tagline: "Lilac clouds, frosted glass and a quiet watch face.",
        material: .frosted, card: WidgetColor(hex: 0xF6F1FF), ink: WidgetColor(hex: 0x3D2E5C), accent: WidgetColor(hex: 0x6D4FBF),
        wallpaperInk: WidgetColor(hex: 0x3D2E5C), wallpaperAccent: WidgetColor(hex: 0x5E43A8),
        font: .serif, cornerRadius: 22, textStyle: .elegant, clockFace: .analog, palette: .pastel, photoFilter: .dreamy,
        noteColor: .purple, sticker: .sparkles, stickerFinish: .soft, stickerColor: WidgetColor(hex: 0xC9B6FF), iconSymbol: "sparkles",
        wallpaper: .art(ArtPiece(style: .clouds, palette: .pastel)),
        photos: pool("Blossom", "Soft & Dreamy"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.quote, .medium, 2, 0, Kit.words("dream in soft focus", style: .elegant)),
            KitItem(.moon, .small, 4, 0),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.polaroids, .large, 0, 1, Kit.prints(from: 0)),
            KitItem(.calendar, .medium, 2, 1),
            KitItem(.photo, .medium, 4, 1, Kit.photo(6)),
            KitItem(.nowPlaying, .medium, 2, 2),
            KitItem(.note, .medium, 4, 2),
            KitItem(.quote, .small, 0, 3, Kit.words("be gentle", style: .script, bare: true)),
            KitItem(.weather, .small, 1, 3),
        ])

    /// Bubblegum, checkerboard and glitter words.
    public static let candyPop = WidgetTheme(
        id: "candyPop", title: "Candy Pop", tagline: "Bubblegum checks, glitter words and a flip clock.",
        material: .paper, card: WidgetColor(hex: 0xFFFFFF), ink: WidgetColor(hex: 0x3B1E4A), accent: WidgetColor(hex: 0xD6336C),
        wallpaperInk: WidgetColor(hex: 0x3B1E4A), wallpaperAccent: WidgetColor(hex: 0xC2255C),
        font: .expanded, cornerRadius: 26, textStyle: .bold, clockFace: .flip, palette: .candy, photoFilter: .none,
        noteColor: .pink, sticker: .star, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xFF5F8F), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .checker, palette: .candy)),
        photos: pool("Retro Things", "Neon Motels"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("sweet", .glitter, style: .chunky)),
            KitItem(.clock, .small, 2, 0),
            KitItem(.sticker, .medium, 3, 0),
            KitItem(.photo, .small, 5, 0, Kit.photo(0)),
            KitItem(.photo, .large, 0, 1, Kit.photo(1)),
            KitItem(.todo, .medium, 2, 1, Kit.list("to-do")),
            KitItem(.battery, .small, 4, 1),
            KitItem(.calendar, .small, 5, 1),
            KitItem(.nowPlaying, .medium, 2, 2),
            KitItem(.quote, .medium, 4, 2, Kit.words("Treat yourself.", style: .bold)),
            KitItem(.dots, .small, 0, 3),
            KitItem(.shortcuts, .medium, 1, 3, Kit.bare),
            KitItem(.quote, .small, 3, 3, Kit.words("pop!", style: .chunky, bare: true)),
        ])

    // MARK: Colour

    /// Deep sea blues under clear glass.
    public static let oceanGlass = WidgetTheme(
        id: "oceanGlass", title: "Ocean Glass", tagline: "Deep-sea blues under clear glass, and slow waves.",
        material: .glass, card: WidgetColor(hex: 0x0B2A3F), ink: WidgetColor(hex: 0xEAF8FF), accent: WidgetColor(hex: 0x3FD5F0),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x9EE6F9),
        font: .standard, cornerRadius: 24, textStyle: .modern, clockFace: .digital, palette: .ocean, photoFilter: .cool,
        noteColor: .blue, sticker: .sparkles, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0x9EE6F9), iconSymbol: "drop.fill",
        wallpaper: .art(ArtPiece(style: .waves, palette: .ocean)),
        photos: pool("Ocean", "Deep Water"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.weather, .medium, 2, 0),
            KitItem(.photo, .medium, 4, 0, Kit.photo(0)),
            KitItem(.visualizer, .medium, 0, 1),
            KitItem(.quote, .large, 2, 1, Kit.words("Go where the water is clear.", style: .editorial)),
            KitItem(.calendar, .small, 4, 1),
            KitItem(.battery, .small, 5, 1),
            KitItem(.nowPlaying, .medium, 0, 2),
            KitItem(.photo, .medium, 4, 2, Kit.photo(1)),
            KitItem(.todo, .medium, 0, 3),
            KitItem(.focus, .medium, 2, 3),
            KitItem(.sticker, .small, 4, 3),
            KitItem(.moon, .small, 5, 3),
        ])

    /// A synthwave sunset, tapes and records, windows down.
    public static let sunsetDrive = WidgetTheme(
        id: "sunsetDrive", title: "Sunset Drive", tagline: "A synthwave sunset, tapes and records, windows down.",
        material: .dark, card: WidgetColor(hex: 0x1E0F24), ink: WidgetColor(hex: 0xFFE9DA), accent: WidgetColor(hex: 0xFF8A5C),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFD56B),
        font: .expanded, cornerRadius: 16, textStyle: .poster, clockFace: .flip, palette: .sunset, photoFilter: .warm,
        noteColor: .yellow, sticker: .star, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xFFA36C), iconSymbol: "car.fill",
        wallpaper: .art(ArtPiece(style: .synthwave, palette: .sunset)),
        photos: pool("Night Drive", "Palm Sunsets"),
        kit: [
            KitItem(.wordArt, .medium, 0, 0, Kit.wordArt("Golden hour", .holo, style: .script)),
            KitItem(.clock, .small, 2, 0),
            KitItem(.vinyl, .medium, 3, 0),
            KitItem(.photo, .small, 5, 0, Kit.photo(0)),
            KitItem(.photo, .large, 0, 1, Kit.photo(1)),
            KitItem(.cassette, .medium, 2, 1),
            KitItem(.weather, .small, 4, 1),
            KitItem(.calendar, .small, 5, 1),
            KitItem(.quote, .medium, 2, 2, Kit.words("Windows down.", style: .poster)),
            KitItem(.nowPlaying, .medium, 4, 2),
            KitItem(.photo, .medium, 0, 3, Kit.strip(from: 2)),
            KitItem(.quote, .small, 2, 3, Kit.words("drive slow", style: .script, bare: true)),
        ])

    /// Pine green, rain on the window, a typewriter and the kettle on.
    public static let forestCabin = WidgetTheme(
        id: "forestCabin", title: "Forest Cabin", tagline: "Pine green, rain on the glass and the kettle on.",
        material: .paper, card: WidgetColor(hex: 0x1F3327), ink: WidgetColor(hex: 0xF1EAD8), accent: WidgetColor(hex: 0xA9D18E),
        wallpaperInk: WidgetColor(hex: 0xF1EAD8), wallpaperAccent: WidgetColor(hex: 0xE3F2C1),
        font: .serif, cornerRadius: 14, textStyle: .typewriter, clockFace: .analog, palette: .forest, photoFilter: .vintage,
        noteColor: .green, sticker: .cloud, stickerFinish: .soft, stickerColor: WidgetColor(hex: 0xE3F2C1), iconSymbol: "tree.fill",
        wallpaper: .art(ArtPiece(style: .rain, palette: .forest)),
        photos: pool("Mist & Forest", "Rainy Window"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.weather, .medium, 2, 0),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.date, .small, 5, 0),
            KitItem(.photo, .large, 0, 1, Kit.photo(0)),
            KitItem(.note, .medium, 2, 1),
            KitItem(.photo, .medium, 4, 1, Kit.photo(1)),
            KitItem(.nowPlaying, .medium, 2, 2),
            KitItem(.quote, .medium, 4, 2, Kit.words("Put the kettle on.", style: .typewriter)),
            KitItem(.todo, .medium, 0, 3),
            KitItem(.focus, .medium, 2, 3),
            KitItem(.photo, .small, 4, 3, Kit.photo(2)),
            KitItem(.moon, .small, 5, 3),
        ])

    /// Terracotta and sand, dunes and desert flowers.
    public static let desertBloom = WidgetTheme(
        id: "desertBloom", title: "Desert Bloom", tagline: "Terracotta and sand, warm dunes and desert flowers.",
        material: .paper, card: WidgetColor(hex: 0xF7EBDD), ink: WidgetColor(hex: 0x4A2515), accent: WidgetColor(hex: 0xA84A26),
        wallpaperInk: WidgetColor(hex: 0xFFF1D6), wallpaperAccent: WidgetColor(hex: 0xF4D19B),
        font: .serif, cornerRadius: 18, textStyle: .elegant, clockFace: .minimal, palette: .desert, photoFilter: .warm,
        noteColor: .yellow, sticker: .flower, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0xF4D19B), iconSymbol: "sun.haze.fill",
        wallpaper: .art(ArtPiece(style: .dunes, palette: .desert)),
        photos: pool("Desert", "Desert Fire"),
        kit: [
            KitItem(.quote, .medium, 0, 0, Kit.words("Bloom where you are.", style: .elegant)),
            KitItem(.clock, .small, 2, 0),
            KitItem(.photo, .large, 3, 0, Kit.photo(0)),
            KitItem(.sticker, .small, 5, 0),
            KitItem(.calendar, .medium, 0, 1),
            KitItem(.weather, .small, 2, 1),
            KitItem(.date, .small, 5, 1),
            KitItem(.photo, .medium, 0, 2, Kit.photo(1)),
            KitItem(.nowPlaying, .medium, 2, 2),
            KitItem(.todo, .medium, 4, 2),
            KitItem(.dots, .medium, 0, 3),
            KitItem(.quote, .small, 2, 3, Kit.words("sun-kissed", style: .script, bare: true)),
        ])
}
