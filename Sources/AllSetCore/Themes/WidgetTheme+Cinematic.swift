import Foundation

extension WidgetTheme {
    /// The featured desktop from the approved Themes design. The wallpaper
    /// ships with the app; every preview uses the same kit that Apply installs.
    public static let midnightAurora = WidgetTheme(
        id: "midnightAurora", title: "Midnight Aurora",
        tagline: "Northern lights, clear glass and a little room to breathe.",
        material: .glass, card: WidgetColor(hex: 0x132C58), ink: WidgetColor(hex: 0xF2F7FF),
        accent: WidgetColor(hex: 0x87DBFF), wallpaperInk: WidgetColor(hex: 0xFFFFFF),
        wallpaperAccent: WidgetColor(hex: 0x8EDCFF), font: .standard, cornerRadius: 22,
        textStyle: .modern, clockFace: .digital, palette: .aurora, photoFilter: .cool,
        noteColor: .blue, sticker: .sparkles, stickerFinish: .chrome,
        stickerColor: WidgetColor(hex: 0xB9A5FF), iconSymbol: "sparkles",
        wallpaper: .photo(.bundled("midnight-aurora.jpg")), photos: [],
        kit: [
            KitItem(.clock, .medium, 0, 1),
            KitItem(.weather, .small, 3, 0),
            KitItem(.calendar, .small, 4, 0),
            KitItem(.photo, .small, 5, 0, auroraPhoto),
            KitItem(.nowPlaying, .medium, 3, 1),
            KitItem(.photo, .small, 5, 1, auroraPhoto),
            KitItem(.moon, .small, 0, 0),
            KitItem(.date, .small, 1, 0),
            KitItem(.quote, .medium, 0, 2, Kit.words("Find your quiet.", style: .modern)),
            KitItem(.focus, .medium, 2, 2),
            KitItem(.battery, .small, 4, 2),
            KitItem(.sticker, .small, 5, 2),
        ])

    private static let auroraPhoto: Kit.Configure = { widget, _ in
        widget.options.images = [.bundled("midnight-aurora.jpg")]
        widget.options.photoFrame = .fullBleed
    }
}
