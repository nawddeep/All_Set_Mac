import Foundation

/// Sparse, editable desktop compositions developed from the second reference set.
/// The supplied files are photographs of screens, so their low-resolution UI and
/// third-party imagery are references only; every installed pixel is native or
/// comes from the existing high-resolution, bundled art library.
public enum DatasetTwoThemes {
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

    private static func picture(_ name: String, frame: PhotoFrame = .fullBleed) -> Kit.Configure {
        { widget, _ in
            widget.options.images = [.bundled("edit-\(name).jpg")]
            widget.options.photoFrame = frame
        }
    }

    private static func make(
        _ id: String, _ title: String, _ tagline: String,
        wallpaper: WallpaperSource, card: Int, ink: Int, accent: Int,
        palette: ArtPalette, font: WidgetFont, style: TextStyle,
        material: WidgetMaterial, radius: Double, dark: Bool,
        mood: ThemeCollection, tags: String, philosophy: String,
        hero: Int, flankers: [Int], kit: [KitItem]
    ) -> Design {
        let theme = WidgetTheme(
            id: id, title: title, tagline: tagline, material: material,
            card: WidgetColor(hex: card), ink: WidgetColor(hex: ink), accent: WidgetColor(hex: accent),
            wallpaperInk: WidgetColor(hex: ink), wallpaperAccent: WidgetColor(hex: accent),
            font: font, cornerRadius: radius, textStyle: style, clockFace: .minimal,
            palette: palette, photoFilter: .mono, noteColor: dark ? .blue : .green,
            sticker: .star, stickerFinish: .outline, stickerColor: WidgetColor(hex: accent),
            iconSymbol: "square.grid.2x2", wallpaper: wallpaper, photos: [],
            kit: kit.map { item in
                KitItem(item.kind, item.size, item.column, item.row) { widget, theme in
                    item.configure(&widget, theme)
                    if widget.options.font == nil { widget.options.font = theme.font }
                    if widget.options.cornerRadius == nil { widget.options.cornerRadius = theme.cornerRadius }
                    if widget.material != .photo { widget.options.background = nil }
                    widget.options.animateArt = false
                    widget.options.neonFlicker = false
                }
            })
        return Design(theme: theme, collections: [.datasetTwo, mood], tags: tags,
                      philosophy: philosophy, cardArt: .init(hero: hero, flankers: flankers),
                      lighting: ThemeAccent(primary: WidgetColor(hex: accent).lit,
                                            secondary: WidgetColor(hex: card).paled,
                                            glowIntensity: dark ? 0.7 : 0.5), dark: dark)
    }

    public static let all: [Design] = [
        make("nocturneIndex", "Nocturne Index", "An after-hours music desk in charcoal, silver and paper.",
             wallpaper: .art(.init(style: .film, palette: .shadow)),
             card: 0x202024, ink: 0xF1EEE8, accent: 0xB99C72, palette: .shadow,
             font: .serif, style: .editorial, material: .paper, radius: 7, dark: true,
             mood: .night, tags: "black monochrome music editorial collage contact sheet dark",
             philosophy: "A narrow left contact sheet carries music and a single analog photograph. Time and a live calendar balance the right edge, leaving the dark center available for work.",
             hero: 2, flankers: [0, 1, 4, 6], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.calendar, .small, 5, 0),
                KitItem(.photo, .medium, 0, 1, picture("analog-studio")),
                KitItem(.nowPlaying, .medium, 0, 2),
                KitItem(.quote, .medium, 4, 1, Kit.words("AFTER THE HOURS", style: .editorial)),
                KitItem(.moon, .small, 5, 2),
                KitItem(.vinyl, .medium, 4, 3),
             ]),
        make("herbariumMargin", "Herbarium Margin", "A white botanical page with a useful, quiet margin.",
             wallpaper: .photo(.bundled("edit-ivory-paper.jpg")),
             card: 0xF4F2ED, ink: 0x343B37, accent: 0x648774, palette: .mono,
             font: .serif, style: .elegant, material: .paper, radius: 5, dark: false,
             mood: .minimal, tags: "white botanical flower cream page planner calendar airy",
             philosophy: "A full-bleed botanical print occupies one right-hand frame. The date, agenda and notes sit on the left like a small paper workspace; the middle remains white.",
             hero: 3, flankers: [0, 2, 4, 5], kit: [
                KitItem(.clock, .medium, 0, 0, Kit.bare),
                KitItem(.date, .small, 5, 0, Kit.bare),
                KitItem(.calendar, .medium, 0, 1),
                KitItem(.photo, .large, 4, 1, picture("botanical-paper")),
                KitItem(.todo, .medium, 0, 2, Kit.list("today's notes")),
                KitItem(.weather, .small, 0, 3),
                KitItem(.focus, .small, 1, 3),
             ]),
        make("grandTour", "Grand Tour", "Black-and-white motoring prints with a disciplined instrument panel.",
             wallpaper: .photo(.bundled("edit-silver-current.jpg")),
             card: 0x181B1E, ink: 0xF3F3EF, accent: 0x84ACBA, palette: .mono,
             font: .condensed, style: .modern, material: .paper, radius: 4, dark: true,
             mood: .cinematic, tags: "monochrome car motoring photography instrument panel silver",
             philosophy: "A wide racing photograph leads the left side; a compact world clock and timer give the right side the feel of a dashboard. The center stays clear, even on a laptop screen.",
             hero: 2, flankers: [0, 1, 3, 5], kit: [
                KitItem(.clock, .medium, 0, 0),
                KitItem(.weather, .small, 5, 0),
                KitItem(.photo, .medium, 0, 1, picture("track-day")),
                KitItem(.stopwatch, .small, 0, 2),
                KitItem(.clock, .medium, 4, 1, { widget, _ in widget.options.clockFace = .world }),
                KitItem(.metric, .small, 5, 2, { widget, _ in widget.options.metric = .cpu }),
                KitItem(.nowPlaying, .medium, 4, 3),
             ]),
    ]
}
