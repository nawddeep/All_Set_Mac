import CoreGraphics
import Foundation

/// A whole desktop look: how every widget's card, colors and type are set,
/// the live wallpaper behind them, and a starter layout ("kit") like the
/// setups people share. Applying one restyles the widgets already there.
public struct WidgetTheme: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let tagline: String
    /// The card style for widgets that have one.
    public let material: WidgetMaterial
    /// The card's color.
    public let card: WidgetColor
    /// Text on the card.
    public let ink: WidgetColor
    public let accent: WidgetColor
    /// Text and icons on widgets with no card, sitting on the wallpaper.
    public let wallpaperInk: WidgetColor
    public let wallpaperAccent: WidgetColor
    public let font: WidgetFont
    public let cornerRadius: Double
    public let textStyle: TextStyle
    public let clockFace: ClockFace
    /// For art, mesh backgrounds and Live Scenes.
    public let palette: ArtPalette
    public let photoFilter: PhotoFilter
    public let noteColor: NoteColor
    public let sticker: StickerShape
    public let stickerFinish: StickerFinish
    public let stickerColor: WidgetColor
    /// The icon Shortcuts widgets use.
    public let iconSymbol: String
    public let wallpaper: WallpaperSource
    /// Photos for the kit's photo widgets.
    public let photos: [WebPhoto]
    public let kit: [KitItem]

    /// The same widget, dressed in this theme. Kinds that paint their own
    /// backgrounds keep them; widgets with no card stay that way.
    public func styled(_ original: WidgetInstance) -> WidgetInstance {
        var widget = original
        widget.options.cinematicClock = false
        widget.options.cinematicStyle = false
        widget.options.photoFilter = photoFilter
        switch widget.kind {
        case .note:
            widget.options.noteColor = noteColor
        case .sticker:
            widget.tint = stickerColor
            widget.options.sticker = sticker
            widget.options.stickerFinish = stickerFinish
        case .polaroids, .vinyl, .moon, .daylight, .retroWindow, .enso, .magazine, .jersey, .playerCard, .pitch, .scoreboard, .ticket:
            // These paint their own look (the magazine, window and enso are their theme).
            break
        case .cassette, .visualizer:
            // They glow in the theme's color.
            widget.tint = wallpaperAccent
        case .wordArt:
            widget.tint = wallpaperAccent
            widget.options.textStyle = textStyle
        case .ambient:
            widget.options.art.palette = palette
            widget.options.textStyle = textStyle
        default:
            // A setup's colors replace any design theme.
            widget.options.designTheme = nil
            if widget.material != .clear { widget.material = material }
            let bare = widget.material == .clear
            widget.tint = bare ? wallpaperAccent : card
            widget.options.ink = bare ? wallpaperInk : ink
            widget.options.accent = bare ? wallpaperAccent : accent
            widget.options.art.palette = palette
            if [.quote, .countdown, .neon].contains(widget.kind) { widget.options.textStyle = textStyle }
            if widget.kind == .clock { widget.options.clockFace = clockFace }
            if widget.kind == .shortcuts {
                for index in widget.options.shortcuts.indices { widget.options.shortcuts[index].symbol = iconSymbol }
            }
        }
        return widget
    }

    /// The kit's widgets on a screen whose visible area is `bounds`, from the top left.
    public func kitWidgets(screenName: String?, bounds: CGSize) -> [WidgetInstance] {
        let step = WidgetSize.small.dimensions.width + WidgetLayout.spacing
        return kit.map { item in
            let offset = CGPoint(x: WidgetLayout.margin + Double(item.column) * step,
                                 y: WidgetLayout.margin + Double(item.row) * step)
            var widget = styled(WidgetInstance(kind: item.kind, size: item.size, screenName: screenName, offset: offset))
            item.configure(&widget, self)
            widget.offset = WidgetLayout.snap(widget.offset, size: widget.footprint, within: bounds)
            return widget
        }
    }

    /// Photo `index` of the theme's set, going round.
    public func photo(_ index: Int) -> ImageSource {
        let photos = photos.isEmpty ? CuratedBackgrounds.all : photos
        return .web(photos[abs(index) % photos.count])
    }
}

/// One widget in a theme's starter layout, placed on a grid of small-widget cells.
public struct KitItem: Sendable {
    public let kind: WidgetKind
    public let size: WidgetSize
    public let column: Int
    public let row: Int
    public let configure: @Sendable (inout WidgetInstance, WidgetTheme) -> Void

    public init(_ kind: WidgetKind, _ size: WidgetSize, _ column: Int, _ row: Int,
                _ configure: @escaping @Sendable (inout WidgetInstance, WidgetTheme) -> Void = { _, _ in }) {
        self.kind = kind
        self.size = size
        self.column = column
        self.row = row
        self.configure = configure
    }
}

/// Small pieces for configuring kit widgets.
enum Kit {
    typealias Configure = @Sendable (inout WidgetInstance, WidgetTheme) -> Void

    static func words(_ text: String, style: TextStyle? = nil, kicker: String = "", bare: Bool = false) -> Configure {
        { widget, theme in
            widget.options.quoteSource = .custom
            widget.options.customText = text
            widget.options.caption = kicker
            if let style { widget.options.textStyle = style }
            if bare { clear(&widget, theme) }
        }
    }

    /// Straight on the wallpaper, no card.
    static func clear(_ widget: inout WidgetInstance, _ theme: WidgetTheme) {
        widget.material = .clear
        widget.tint = theme.wallpaperAccent
        widget.options.ink = theme.wallpaperInk
        widget.options.accent = theme.wallpaperAccent
    }

    static let bare: Configure = { widget, theme in clear(&widget, theme) }

    static func photo(_ index: Int) -> Configure {
        { widget, theme in
            widget.options.images = [theme.photo(index)]
            widget.options.photoFrame = .fullBleed
        }
    }

    static func collage(from index: Int) -> Configure {
        { widget, theme in
            widget.options.images = (0..<9).map { theme.photo(index + $0) }
            widget.options.photoFrame = .collage
        }
    }

    static func prints(from index: Int) -> Configure {
        { widget, theme in widget.options.images = (0..<6).map { theme.photo(index + $0) } }
    }

    static func sticker(text: String) -> Configure {
        { widget, _ in widget.options.stickerText = text }
    }

    static func list(_ title: String) -> Configure {
        { widget, _ in widget.options.listTitle = title }
    }

    /// A neon sign; it glows in the theme's wallpaper color unless given one.
    static func neon(_ text: String, color: WidgetColor? = nil) -> Configure {
        { widget, _ in
            widget.options.customText = text
            if let color { widget.tint = color }
        }
    }

    static func strip(from index: Int) -> Configure {
        { widget, theme in
            widget.options.images = (0..<6).map { theme.photo(index + $0) }
            widget.options.photoFrame = .filmStrip
        }
    }
}

extension WidgetTheme {
    public static let all: [WidgetTheme] = moodboards + fandom + colour + [midnightAurora, cloudNine, goodThings, pinkLatte, coquette, grunge, diva, luxeNoir, sepia,
                                            vigilante, neonNights, darkAcademia, midnightLofi, goth]

    /// Whether the wallpaper is dark (a night photo counts as dark).
    public var isDark: Bool {
        switch wallpaper {
        case .art(let piece): !piece.palette.isLight
        case .photo, .video, .library: true
        }
    }

    public static func named(_ id: String) -> WidgetTheme? { all.first { $0.id == id } }

    /// Baby-blue sky, cream paper cards, soft stars.
    public static let cloudNine = WidgetTheme(
        id: "cloudNine", title: "Cloud Nine", tagline: "Baby-blue skies, cream paper cards and soft stars.",
        material: .paper, card: WidgetColor(hex: 0xF4EEE4), ink: WidgetColor(hex: 0x5B5048), accent: WidgetColor(hex: 0x8FA9C8),
        wallpaperInk: WidgetColor(hex: 0x3F4E66), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .serif, cornerRadius: 20, textStyle: .classic, clockFace: .digital, palette: .sky, photoFilter: .fade,
        noteColor: .blue, sticker: .star, stickerFinish: .soft, stickerColor: WidgetColor(hex: 0x9DBBEA), iconSymbol: "star.fill",
        wallpaper: .art(ArtPiece(style: .clouds, palette: .sky)),
        photos: CuratedBackgrounds.collection("Soft & Dreamy") + CuratedBackgrounds.collection("Golden Hour"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.sticker, .medium, 2, 0),
            KitItem(.photo, .medium, 4, 0, Kit.photo(0)),
            KitItem(.quote, .small, 0, 1, Kit.words("You can create the life you want.")),
            KitItem(.nowPlaying, .medium, 1, 1),
            KitItem(.stopwatch, .small, 3, 1),
            KitItem(.quote, .large, 4, 1, Kit.words("Success comes from what you do consistently.", style: .editorial)),
            KitItem(.todo, .large, 0, 2),
            KitItem(.shortcuts, .medium, 2, 2, Kit.bare),
            KitItem(.quote, .small, 2, 3, Kit.words("it comes in waves", style: .chunky)),
            KitItem(.photo, .small, 3, 3, Kit.photo(3)),
        ])

    /// All black, big condensed type, focus mode.
    public static let goodThings = WidgetTheme(
        id: "goodThings", title: "Good Things", tagline: "All black, huge type, locked-in focus.",
        material: .frosted, card: WidgetColor(hex: 0x17171A), ink: WidgetColor(hex: 0xF2F2F2), accent: WidgetColor(hex: 0xFFFFFF),
        wallpaperInk: WidgetColor(hex: 0xF2F2F2), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .condensed, cornerRadius: 14, textStyle: .poster, clockFace: .digital, palette: .mono, photoFilter: .mono,
        noteColor: .yellow, sticker: .sparkles, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xC0C0C0), iconSymbol: "circle.fill",
        wallpaper: .art(ArtPiece(style: .film, palette: .mono)),
        photos: CuratedBackgrounds.collection("City Lights"),
        kit: [
            KitItem(.todo, .medium, 0, 0, Kit.list("reminders")),
            KitItem(.nowPlaying, .medium, 0, 1),
            KitItem(.focus, .medium, 0, 2),
            KitItem(.quote, .small, 0, 3, Kit.words("God. Goals. Discipline.", bare: true)),
            KitItem(.quote, .large, 2, 0, Kit.words("Good things\nare coming.", style: .poster, kicker: "Daily Reminder", bare: true)),
            KitItem(.clock, .small, 5, 0),
            KitItem(.quote, .small, 5, 1, Kit.words("Don't be busy. Be productive.", style: .editorial, bare: true)),
            KitItem(.calendar, .small, 5, 2),
        ])

    /// Pink gradient, mauve glass, a grid of photos.
    public static let pinkLatte = WidgetTheme(
        id: "pinkLatte", title: "Pink Latte", tagline: "Blush gradient, mauve glass and a photo grid.",
        material: .frosted, card: WidgetColor(hex: 0x8E5E72), ink: WidgetColor(hex: 0xFFFFFF), accent: WidgetColor(hex: 0xF7C6D9),
        wallpaperInk: WidgetColor(hex: 0x6B3A4E), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .rounded, cornerRadius: 22, textStyle: .modern, clockFace: .digital, palette: .blush, photoFilter: .warm,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xF29BB8), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .blobs, palette: .blush)),
        photos: CuratedBackgrounds.collection("Soft & Dreamy") + CuratedBackgrounds.collection("Golden Hour"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.stopwatch, .small, 2, 0),
            KitItem(.photo, .small, 3, 0, Kit.photo(1)),
            KitItem(.photo, .small, 4, 0, Kit.photo(2)),
            KitItem(.focus, .small, 5, 0),
            KitItem(.calendar, .small, 0, 1),
            KitItem(.photo, .small, 1, 1, Kit.photo(4)),
            KitItem(.quote, .medium, 2, 1, Kit.words("Proud of you for showing up today.")),
            KitItem(.photo, .large, 4, 1, Kit.collage(from: 5)),
            KitItem(.nowPlaying, .medium, 0, 2),
            KitItem(.todo, .medium, 2, 2),
        ])

    /// Bows, hearts and prints on blush white.
    public static let coquette = WidgetTheme(
        id: "coquette", title: "Coquette", tagline: "Hearts, polaroids and every shade of pink.",
        material: .paper, card: WidgetColor(hex: 0xFFF0F4), ink: WidgetColor(hex: 0x7A2E3F), accent: WidgetColor(hex: 0xE0557A),
        wallpaperInk: WidgetColor(hex: 0x7A2E3F), wallpaperAccent: WidgetColor(hex: 0xE0557A),
        font: .serif, cornerRadius: 16, textStyle: .script, clockFace: .digital, palette: .coquette, photoFilter: .fade,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xE0557A), iconSymbol: "heart.fill",
        wallpaper: .art(ArtPiece(style: .hearts, palette: .coquette)),
        photos: CuratedBackgrounds.collection("Portraits & Pets") + CuratedBackgrounds.collection("Soft & Dreamy"),
        kit: [
            KitItem(.polaroids, .large, 0, 0, Kit.prints(from: 0)),
            KitItem(.shortcuts, .medium, 2, 0, Kit.bare),
            KitItem(.sticker, .small, 2, 1),
            KitItem(.todo, .small, 3, 1),
            KitItem(.photo, .large, 4, 0, Kit.photo(6)),
            KitItem(.quote, .small, 0, 2, Kit.words("xoxo, be gentle with yourself", bare: true)),
            KitItem(.calendar, .small, 1, 2),
            KitItem(.nowPlaying, .medium, 2, 2),
            KitItem(.clock, .medium, 4, 2),
        ])

    /// Black-and-white, flip clock, a spiral and a collage.
    public static let grunge = WidgetTheme(
        id: "grunge", title: "Grunge", tagline: "Black-and-white collage, a flip clock and a spiral.",
        material: .paper, card: WidgetColor(hex: 0x262626), ink: WidgetColor(hex: 0xEDEDED), accent: WidgetColor(hex: 0xFFFFFF),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .condensed, cornerRadius: 12, textStyle: .typewriter, clockFace: .flip, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .spiral, stickerFinish: .outline, stickerColor: WidgetColor(hex: 0xFFFFFF), iconSymbol: "eye.fill",
        wallpaper: .art(ArtPiece(style: .spiral, palette: .mono)),
        photos: CuratedBackgrounds.collection("City Lights") + CuratedBackgrounds.collection("Portraits & Pets"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.sticker, .small, 2, 0),
            KitItem(.photo, .small, 3, 0, Kit.photo(0)),
            KitItem(.nowPlaying, .medium, 4, 0),
            KitItem(.calendar, .large, 0, 1),
            KitItem(.photo, .large, 2, 1, Kit.collage(from: 1)),
            KitItem(.todo, .medium, 4, 1),
            KitItem(.photo, .medium, 4, 2, Kit.photo(12)),
        ])

    /// Leopard, hot pink and black-and-white photos.
    public static let diva = WidgetTheme(
        id: "diva", title: "Diva", tagline: "Leopard print, hot pink and black-and-white glamour.",
        material: .frosted, card: WidgetColor(hex: 0x0E0B0C), ink: WidgetColor(hex: 0xFFB6D9), accent: WidgetColor(hex: 0xFF8CC6),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFF8CC6),
        font: .serif, cornerRadius: 16, textStyle: .script, clockFace: .digital, palette: .diva, photoFilter: .noir,
        noteColor: .pink, sticker: .crown, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xFF8CC6), iconSymbol: "crown.fill",
        wallpaper: .art(ArtPiece(style: .leopard, palette: .diva)),
        photos: CuratedBackgrounds.collection("Portraits & Pets") + CuratedBackgrounds.collection("City Lights"),
        kit: [
            KitItem(.clock, .small, 0, 0),
            KitItem(.photo, .medium, 1, 0, Kit.photo(0)),
            KitItem(.sticker, .medium, 3, 0, Kit.sticker(text: "Diva")),
            KitItem(.photo, .small, 5, 0, Kit.photo(1)),
            KitItem(.nowPlaying, .medium, 0, 1),
            KitItem(.polaroids, .large, 2, 1, Kit.prints(from: 2)),
            KitItem(.photo, .large, 4, 1, Kit.photo(8)),
            KitItem(.calendar, .medium, 0, 2),
        ])

    /// Monochrome luxury: white cards, thin serif, the city at night.
    public static let luxeNoir = WidgetTheme(
        id: "luxeNoir", title: "Luxe Noir", tagline: "White cards, fine serif and the city at night.",
        material: .paper, card: WidgetColor(hex: 0xFAFAFA), ink: WidgetColor(hex: 0x111111), accent: WidgetColor(hex: 0x111111),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFFFFF),
        font: .serif, cornerRadius: 6, textStyle: .elegant, clockFace: .stacked, palette: .mono, photoFilter: .noir,
        noteColor: .yellow, sticker: .star, stickerFinish: .solid, stickerColor: WidgetColor(hex: 0x111111), iconSymbol: "star.fill",
        wallpaper: .photo(.web(CuratedBackgrounds.collection("City Lights").first ?? CuratedBackgrounds.suggestion(0))),
        photos: CuratedBackgrounds.collection("Portraits & Pets") + CuratedBackgrounds.collection("City Lights"),
        kit: [
            KitItem(.photo, .small, 0, 0, Kit.photo(0)),
            KitItem(.quote, .medium, 1, 0, Kit.words("Rich in taste, quiet in noise.", style: .editorial)),
            KitItem(.photo, .large, 3, 0, Kit.photo(3)),
            KitItem(.photo, .medium, 0, 1, Kit.photo(5)),
            KitItem(.clock, .small, 2, 1, Kit.bare),
            KitItem(.calendar, .small, 0, 2),
        ])

    /// Warm film tones, big type, old photos.
    public static let sepia = WidgetTheme(
        id: "sepia", title: "Sepia Swag", tagline: "Warm film tones, big type and old photographs.",
        material: .frosted, card: WidgetColor(hex: 0x3B3128), ink: WidgetColor(hex: 0xE8DCC8), accent: WidgetColor(hex: 0xC8A97E),
        wallpaperInk: WidgetColor(hex: 0xE8DCC8), wallpaperAccent: WidgetColor(hex: 0xC8A97E),
        font: .condensed, cornerRadius: 18, textStyle: .poster, clockFace: .digital, palette: .mocha, photoFilter: .vintage,
        noteColor: .yellow, sticker: .bolt, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xC8A97E), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .film, palette: .mocha)),
        photos: CuratedBackgrounds.collection("Golden Hour") + CuratedBackgrounds.collection("Desert"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.photo, .small, 2, 0, Kit.photo(0)),
            KitItem(.calendar, .small, 3, 0),
            KitItem(.photo, .large, 4, 0, Kit.collage(from: 2)),
            KitItem(.quote, .small, 0, 1, { widget, _ in
                // A white card with black type, like a sticker on the wall.
                widget.options.quoteSource = .custom
                widget.options.customText = "#swag"
                widget.options.textStyle = .poster
                widget.material = .paper
                widget.tint = WidgetColor(hex: 0xF4EEE4)
                widget.options.ink = WidgetColor(hex: 0x111111)
            }),
            KitItem(.photo, .medium, 1, 1, Kit.photo(6)),
            KitItem(.battery, .small, 3, 1),
            KitItem(.nowPlaying, .medium, 0, 2),
            KitItem(.photo, .medium, 2, 2, Kit.photo(9)),
        ])

    // MARK: Dark

    /// A pitch-black city in the rain, a searchlight on the clouds, signal yellow.
    public static let vigilante = WidgetTheme(
        id: "vigilante", title: "Vigilante", tagline: "A city in the rain, a searchlight in the clouds, signal yellow.",
        material: .frosted, card: WidgetColor(hex: 0x0D0F12), ink: WidgetColor(hex: 0xE6E6E6), accent: WidgetColor(hex: 0xFFD23F),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0xFFD23F),
        font: .condensed, cornerRadius: 10, textStyle: .poster, clockFace: .flip, palette: .shadow, photoFilter: .noir,
        noteColor: .yellow, sticker: .moon, stickerFinish: .chrome, stickerColor: WidgetColor(hex: 0xC9CED6), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .skyline, palette: .shadow)),
        photos: CuratedBackgrounds.collection("City Lights") + CuratedBackgrounds.collection("Night & Stars"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.terminal, .medium, 0, 1),
            KitItem(.nowPlaying, .medium, 0, 2),
            KitItem(.quote, .large, 2, 0, Kit.words("Be the light\nin the dark.", style: .poster, kicker: "Night Shift", bare: true)),
            KitItem(.calendar, .small, 2, 2),
            KitItem(.system, .small, 3, 2),
            KitItem(.neon, .small, 2, 3, Kit.neon("rise")),
            KitItem(.focus, .medium, 4, 0),
            KitItem(.photo, .small, 4, 1, Kit.photo(0)),
            KitItem(.photo, .small, 5, 1, Kit.photo(3)),
            KitItem(.dots, .medium, 4, 2),
        ])

    /// Cyberpunk: a neon city, glowing signs, a terminal.
    public static let neonNights = WidgetTheme(
        id: "neonNights", title: "Neon Nights", tagline: "A cyberpunk city, glowing signs and a terminal.",
        material: .frosted, card: WidgetColor(hex: 0x0A0014), ink: WidgetColor(hex: 0xF6F6FF), accent: WidgetColor(hex: 0xFF2BD6),
        wallpaperInk: WidgetColor(hex: 0xFFFFFF), wallpaperAccent: WidgetColor(hex: 0x2DE2E6),
        font: .monospaced, cornerRadius: 16, textStyle: .script, clockFace: .digital, palette: .neon, photoFilter: .cool,
        noteColor: .purple, sticker: .bolt, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xFF2BD6), iconSymbol: "bolt.fill",
        wallpaper: .art(ArtPiece(style: .skyline, palette: .neon)),
        photos: CuratedBackgrounds.collection("City Lights"),
        kit: [
            KitItem(.neon, .medium, 0, 0, Kit.neon("stay wild", color: WidgetColor(hex: 0xFF2BD6))),
            KitItem(.clock, .medium, 2, 0),
            KitItem(.terminal, .large, 4, 0),
            KitItem(.nowPlaying, .medium, 0, 1),
            KitItem(.vinyl, .medium, 2, 1),
            KitItem(.photo, .medium, 0, 2, Kit.photo(2)),
            KitItem(.system, .small, 2, 2),
            KitItem(.dots, .small, 3, 2),
            KitItem(.shortcuts, .medium, 4, 2, Kit.bare),
        ])

    /// Candlelight, old books, gold serif on dark wood.
    public static let darkAcademia = WidgetTheme(
        id: "darkAcademia", title: "Dark Academia", tagline: "Candlelight, old books and gold serif on dark wood.",
        material: .paper, card: WidgetColor(hex: 0x1F1A14), ink: WidgetColor(hex: 0xE8DCC0), accent: WidgetColor(hex: 0xC9A45C),
        wallpaperInk: WidgetColor(hex: 0xE8DCC0), wallpaperAccent: WidgetColor(hex: 0xC9A45C),
        font: .serif, cornerRadius: 8, textStyle: .editorial, clockFace: .analog, palette: .emerald, photoFilter: .vintage,
        noteColor: .yellow, sticker: .moon, stickerFinish: .outline, stickerColor: WidgetColor(hex: 0xC9A45C), iconSymbol: "book.fill",
        wallpaper: .art(ArtPiece(style: .embers, palette: .ember)),
        photos: CuratedBackgrounds.collection("Mist & Forest") + CuratedBackgrounds.collection("Golden Hour"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.quote, .medium, 2, 0, Kit.words("Read more. Scroll less.", style: .editorial)),
            KitItem(.photo, .small, 4, 0, Kit.photo(0)),
            KitItem(.photo, .small, 5, 0, Kit.photo(4)),
            KitItem(.todo, .large, 0, 1, Kit.list("reading list")),
            KitItem(.calendar, .medium, 2, 1),
            KitItem(.focus, .medium, 4, 1),
            KitItem(.photo, .medium, 2, 2, Kit.strip(from: 1)),
            KitItem(.dots, .medium, 4, 2),
            KitItem(.quote, .small, 0, 3, Kit.words("stay curious", style: .gothic, bare: true)),
        ])

    /// Rain on navy glass, a record spinning, study mode.
    public static let midnightLofi = WidgetTheme(
        id: "midnightLofi", title: "Midnight Lo-fi", tagline: "Rain on the window, a record spinning, study mode.",
        material: .frosted, card: WidgetColor(hex: 0x0B1530), ink: WidgetColor(hex: 0xE6F0FF), accent: WidgetColor(hex: 0x7FB2FF),
        wallpaperInk: WidgetColor(hex: 0xE6F0FF), wallpaperAccent: WidgetColor(hex: 0x7FB2FF),
        font: .rounded, cornerRadius: 20, textStyle: .classic, clockFace: .stacked, palette: .midnight, photoFilter: .cool,
        noteColor: .blue, sticker: .moon, stickerFinish: .soft, stickerColor: WidgetColor(hex: 0x7FB2FF), iconSymbol: "moon.fill",
        wallpaper: .art(ArtPiece(style: .rain, palette: .midnight)),
        photos: CuratedBackgrounds.collection("Night & Stars") + CuratedBackgrounds.collection("Mist & Forest"),
        kit: [
            KitItem(.vinyl, .medium, 0, 0),
            KitItem(.focus, .medium, 0, 1),
            KitItem(.todo, .medium, 0, 2),
            KitItem(.clock, .small, 2, 0, Kit.bare),
            KitItem(.moon, .small, 3, 0),
            KitItem(.sticker, .small, 4, 0),
            KitItem(.quote, .medium, 2, 1, Kit.words("Soft music, slow mind.")),
            KitItem(.dots, .large, 4, 1),
            KitItem(.calendar, .small, 2, 2),
            KitItem(.photo, .small, 3, 2, Kit.photo(0)),
        ])

    /// Black, blood red, gothic letters, embers.
    public static let goth = WidgetTheme(
        id: "goth", title: "Goth", tagline: "Black, blood red, gothic letters and embers.",
        material: .paper, card: WidgetColor(hex: 0x0A0A0A), ink: WidgetColor(hex: 0xEDEDED), accent: WidgetColor(hex: 0xC1121F),
        wallpaperInk: WidgetColor(hex: 0xEDEDED), wallpaperAccent: WidgetColor(hex: 0xE0314B),
        font: .serif, cornerRadius: 4, textStyle: .gothic, clockFace: .words, palette: .cherry, photoFilter: .noir,
        noteColor: .pink, sticker: .heart, stickerFinish: .glossy, stickerColor: WidgetColor(hex: 0xC1121F), iconSymbol: "eye.fill",
        wallpaper: .art(ArtPiece(style: .embers, palette: .cherry)),
        photos: CuratedBackgrounds.collection("Portraits & Pets") + CuratedBackgrounds.collection("Night & Stars"),
        kit: [
            KitItem(.clock, .medium, 0, 0),
            KitItem(.quote, .small, 2, 0, Kit.words("Nevermore.", bare: true)),
            KitItem(.sticker, .small, 3, 0),
            KitItem(.photo, .large, 4, 0, Kit.photo(0)),
            KitItem(.photo, .medium, 0, 1, Kit.strip(from: 2)),
            KitItem(.neon, .small, 2, 1, Kit.neon("bite me")),
            KitItem(.calendar, .small, 3, 1),
            KitItem(.nowPlaying, .medium, 0, 2),
            KitItem(.todo, .medium, 2, 2),
            KitItem(.dots, .medium, 4, 2),
        ])
}
