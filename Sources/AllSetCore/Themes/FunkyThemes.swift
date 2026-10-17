import CoreGraphics
import Foundation

/// The twenty supplied desktop designs. Each keeps its own artwork as the
/// wallpaper, with the painted clock, calendar, music and notes cleared from
/// their cards (`scripts/prepare-funky-themes.py`), and live widgets set into
/// those cards where the design drew them (`FunkyLayouts.swift`).
public enum FunkyThemes {
    public struct Design: Sendable {
        public let theme: WidgetTheme
        public let collections: [ThemeCollection]
        public let tags: String
        public let philosophy: String
        public let cardArt: ThemeCardArt.Picks
        public let lighting: ThemeAccent
        public let dark: Bool
    }

    /// One live widget: where it goes, in pixels of the design's picture, how
    /// far it's resized (as a corner drag would) to fill the card painted for
    /// it, and the ink that reads on that card.
    struct Placement: Sendable {
        let kind: WidgetKind
        let size: WidgetSize
        let origin: CGPoint
        let scale: Double
        let stretch: Double
        let ink: WidgetColor
        let face: ClockFace?

        init(_ kind: WidgetKind, _ size: WidgetSize, x: Double, y: Double, scale: Double, stretch: Double,
             ink: Int, face: ClockFace? = nil) {
            self.kind = kind
            self.size = size
            origin = CGPoint(x: x, y: y)
            self.scale = scale
            self.stretch = stretch
            self.ink = WidgetColor(hex: ink)
            self.face = face
        }
    }

    /// The supplied pictures' size in pixels, which every layout is traced on.
    public static let picture = CGSize(width: 1586, height: 992)

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.theme.id, $0) })
    public static func design(_ id: String) -> Design? { byID[id] }

    /// The space a design's widget offsets are in: its picture's pixels.
    public static func canvas(for id: String) -> CGSize? { layouts[id] == nil ? nil : picture }

    /// A design's widgets placed on a screen so each sits on the card drawn for
    /// it in the wallpaper. The wallpaper fills `screen`, centred and cropped;
    /// widget offsets are measured from the top left of `visible` (the screen
    /// below the menu bar), in layout points that `scale` turns into screen points.
    public static func fitted(_ layout: [WidgetInstance], id: String, screen: CGSize, visible: CGRect) -> (widgets: [WidgetInstance], scale: Double) {
        guard layouts[id] != nil else { return (layout, 1) }
        let cover = max(screen.width / picture.width, screen.height / picture.height)
        let scale = min(max(cover, 0.4), 2)
        // Where the picture's top left lands on the screen, and so where the canvas starts.
        let start = CGPoint(x: (screen.width - picture.width * cover) / 2 - visible.minX,
                            y: (screen.height - picture.height * cover) / 2 - visible.minY)
        // On a screen of another shape the picture loses an edge; a widget on
        // that edge comes in just far enough to stay below the menu bar.
        let room = CGSize(width: visible.width / scale, height: (screen.height - visible.minY) / scale)
        return (layout.map { widget in
            var widget = widget
            widget.offset.x = min(max(widget.offset.x + start.x / scale, 0), max(room.width - widget.footprint.width, 0))
            widget.offset.y = min(max(widget.offset.y + start.y / scale, 0), max(room.height - widget.footprint.height, 0))
            return widget
        }, scale)
    }

    private static func kit(_ id: String) -> [KitItem] {
        (layouts[id] ?? []).map { placement in
            KitItem(placement.kind, placement.size, 0, 0, origin: placement.origin) { widget, theme in
                // On the card painted under it, not on a card of its own.
                Kit.clear(&widget, theme)
                widget.options.ink = placement.ink
                widget.scale = placement.scale
                widget.stretch = placement.stretch
                if let face = placement.face { widget.options.clockFace = face }
            }
        }
    }

    static func make(
        _ id: String, _ title: String, _ tagline: String,
        card: Int, ink: Int, accent: Int, dark: Bool, font: WidgetFont,
        style: TextStyle, filter: PhotoFilter, charm: String,
        collections: [ThemeCollection]? = nil, tags: String? = nil
    ) -> Design {
        let items = kit(id)
        let radius: Double = ["chromeFangEditorial", "acidStarlet", "creamModPoster"].contains(id) ? 7 : 17
        let theme = WidgetTheme(
            id: id, title: title, tagline: tagline, material: .paper,
            card: WidgetColor(hex: card), ink: WidgetColor(hex: ink), accent: WidgetColor(hex: accent),
            wallpaperInk: WidgetColor(hex: ink), wallpaperAccent: WidgetColor(hex: accent),
            font: font, cornerRadius: radius, textStyle: style,
            clockFace: .minimal,
            palette: dark ? .shadow : .mono, photoFilter: filter,
            noteColor: dark ? .purple : .pink,
            sticker: StickerShape(rawValue: charm) ?? .star,
            stickerFinish: dark ? .chrome : .outline, stickerColor: WidgetColor(hex: accent),
            iconSymbol: "sparkles", wallpaper: .photo(.bundled("edit-supplied-\(id).jpg")), photos: [],
            kit: items.map { item in
                KitItem(item.kind, item.size, item.column, item.row, origin: item.origin) { widget, theme in
                    item.configure(&widget, theme)
                    widget.options.font = theme.font
                    widget.options.cornerRadius = theme.cornerRadius
                    widget.options.background = nil
                    widget.options.animateArt = false
                    widget.options.neonFlicker = false
                }
            })
        // The card leads with the largest widget and floats the rest beside it.
        let hero = items.firstIndex { $0.size == .large } ?? 0
        return Design(theme: theme, collections: collections ?? [.funkyThemes, dark ? .night : .designer],
                      tags: "supplied funky collage \(title.lowercased()) \(tags ?? "scrapbook") \(dark ? "dark" : "light")",
                      philosophy: "\(tagline) The design's own collage is the wallpaper; its clock, calendar, music and notes are live widgets set into the cards it drew for them.",
                      cardArt: ThemeCardArt.Picks(hero: hero, flankers: items.indices.filter { $0 != hero }),
                      lighting: ThemeAccent(primary: WidgetColor(hex: accent).lit,
                                            secondary: WidgetColor(hex: accent).paled,
                                            glowIntensity: dark ? 0.75 : 0.55), dark: dark)
    }

    public static let all: [Design] = original + additional

    /// The first twenty supplied designs.
    static let original: [Design] = [
        make("midnightScrapbook", "Midnight Scrapbook", "Charcoal scraps, cream paper and quiet butterfly detail.",
             card: 0x161716, ink: 0xEFE6D6, accent: 0xBC9D74, dark: true, font: .serif,
             style: .handwritten, filter: .mono, charm: "butterfly"),
        make("pinkMotelPop", "Pink Motel Pop", "Blush paper, rose light and playful motel-pop pictures.",
             card: 0xFAEAE3, ink: 0x453134, accent: 0xBF5878, dark: false, font: .serif,
             style: .handwritten, filter: .warm, charm: "heart"),
        make("creamIndieDiary", "Cream Indie Diary", "Aged cream paper, pressed flowers and warm photo prints.",
             card: 0xF3E9D9, ink: 0x51463D, accent: 0xB37B72, dark: false, font: .serif,
             style: .handwritten, filter: .fade, charm: "bow"),
        make("chromeFangEditorial", "Chrome Fang Editorial", "Chrome sculpture and sharp monochrome editorial cards.",
             card: 0xF5F4EF, ink: 0x242429, accent: 0x7197B5, dark: false, font: .serif,
             style: .editorial, filter: .mono, charm: "star"),
        make("laceCityNoir", "Lace City Noir", "A lace-framed skyline and candlelit black-and-white prints.",
             card: 0x151514, ink: 0xF1E9DC, accent: 0xB4A078, dark: true, font: .serif,
             style: .elegant, filter: .mono, charm: "wings"),
        make("vinylBlossom", "Vinyl Blossom", "Blush petals, a vinyl bloom and soft ivory cards.",
             card: 0xFAF1E9, ink: 0x584745, accent: 0xB87A85, dark: false, font: .serif,
             style: .handwritten, filter: .warm, charm: "flower"),
        make("paperHeartsCafe", "Paper Hearts Cafe", "Coffee prints, paper hearts and handwritten little plans.",
             card: 0xF2E7D6, ink: 0x5A4539, accent: 0xB77976, dark: false, font: .serif,
             style: .handwritten, filter: .warm, charm: "heart"),
        make("acidStarlet", "Acid Starlet", "Acid-green stars and high-contrast collage on charcoal.",
             card: 0x171A14, ink: 0xF1F0D9, accent: 0xB7DA42, dark: true, font: .condensed,
             style: .poster, filter: .mono, charm: "star"),
        make("softGrungePolaroid", "Soft Grunge Polaroid", "Weathered paper and faded polaroids in dusty mauve.",
             card: 0xDCD6D0, ink: 0x453D42, accent: 0xA16E82, dark: false, font: .serif,
             style: .typewriter, filter: .fade, charm: "moon"),
        make("monochromeDiva", "Monochrome Diva", "Black satin, pearl light and a winged monochrome silhouette.",
             card: 0x171616, ink: 0xF4ECDD, accent: 0xB89A76, dark: true, font: .serif,
             style: .elegant, filter: .mono, charm: "star"),
        make("velvetCherryNoir", "Velvet Cherry Noir", "Cherry red, burgundy paper and warm nocturnal prints.",
             card: 0x27191D, ink: 0xF6E3D7, accent: 0xBE556C, dark: true, font: .serif,
             style: .handwritten, filter: .warm, charm: "heart"),
        make("blueHazeDiary", "Blue Haze Diary", "Rain-blue paper, moonlit pictures and slate diary cards.",
             card: 0xEEF1F2, ink: 0x374A5B, accent: 0x6C8FAA, dark: false, font: .serif,
             style: .handwritten, filter: .cool, charm: "moon"),
        make("olivePaperStudio", "Olive Paper Studio", "Olive paper, botanical shadows and warm studio photographs.",
             card: 0xEDE8D3, ink: 0x3D4936, accent: 0x8D995C, dark: false, font: .serif,
             style: .handwritten, filter: .warm, charm: "star"),
        make("electricPopGrid", "Electric Pop Grid", "Pink pop cards, neon marks and a bright graphic mosaic.",
             card: 0xF8E8EB, ink: 0x29252F, accent: 0xDA538D, dark: false, font: .condensed,
             style: .poster, filter: .none, charm: "smiley"),
        make("plumStardust", "Plum Stardust", "A plum moon, rose ink and a little stardust.",
             card: 0x2B1E2B, ink: 0xF3D6E0, accent: 0xBB6E9B, dark: true, font: .serif,
             style: .handwritten, filter: .cool, charm: "moon"),
        make("sepiaLibraryClub", "Sepia Library Club", "Espresso paper, amber light and sepia library prints.",
             card: 0x35271C, ink: 0xEED8B4, accent: 0xBE914E, dark: true, font: .serif,
             style: .typewriter, filter: .warm, charm: "star"),
        make("silverBubbleGoth", "Silver Bubble Goth", "Silver hearts, chrome detail and pink-tinted dark cards.",
             card: 0x1D1B1D, ink: 0xF0E5E1, accent: 0xBE85A7, dark: true, font: .serif,
             style: .elegant, filter: .mono, charm: "heart"),
        make("peachFilmBloom", "Peach Film Bloom", "Peach paper, floral light and warm balcony photographs.",
             card: 0xF9E7D8, ink: 0x684B3C, accent: 0xC78065, dark: false, font: .serif,
             style: .handwritten, filter: .warm, charm: "flower"),
        make("forestInkMoodboard", "Forest Ink Moodboard", "Forest ink, parchment notes and quiet botanical pictures.",
             card: 0x1A241C, ink: 0xE9E2CB, accent: 0x96A46E, dark: true, font: .serif,
             style: .handwritten, filter: .fade, charm: "moon"),
        make("creamModPoster", "Cream Mod Poster", "Cream paper, rust accents and bold retro poster shapes.",
             card: 0xF5E8CC, ink: 0x3E352B, accent: 0xB97448, dark: false, font: .serif,
             style: .poster, filter: .warm, charm: "flower"),
    ]
}
