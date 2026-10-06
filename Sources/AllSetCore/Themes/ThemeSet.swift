import CoreGraphics
import Foundation

/// A complete theme world: a visual language, a curated set of widgets laid
/// out as a desktop, a wallpaper, a way of moving, and where it came from.
/// Applying one installs the whole set; each widget stays editable after.
public struct ThemeSet: Identifiable, Sendable {
    /// How the set's widgets are drawn.
    public enum Look: Sendable {
        /// Through the theme engine, in a `DesignTheme` (by id).
        case design(String)
        /// One of the original aesthetic setups (`WidgetTheme`, by id).
        case setup(String)
    }

    public let id: String
    public let name: String
    /// One line for cards.
    public let tagline: String
    /// A short paragraph for the detail page.
    public let description: String
    /// The visual philosophy: what the set is trying to feel like.
    public let philosophy: String
    /// What inspired it, as a genre or mood ("Inspired by nocturnal R&B").
    /// Never an artist's name or mark: those stay in `research`.
    public let inspiration: String?
    public let collections: [ThemeCollection]
    /// Extra words search matches.
    public let tags: String
    public let look: Look
    public let layout: [SetItem]
    public let research: ThemeResearch?
    /// "2026-09-25", for the New shelf.
    public let added: String
    /// Starting popularity until real counts exist (0...100).
    public let baseline: Double
    /// Months (1...12) when the set is in season and ranks higher.
    public let seasons: [Int]
    public let version: Int
    /// The light chosen for the set, when its look's own colors aren't the
    /// ones to use (see `lighting`).
    public let accent: ThemeAccent?

    public init(id: String, name: String, tagline: String, description: String, philosophy: String, inspiration: String? = nil,
                collections: [ThemeCollection], tags: String = "", look: Look, layout: [SetItem], research: ThemeResearch? = nil,
                added: String = "2026-09-24", baseline: Double = 40, seasons: [Int] = [], version: Int = 1,
                accent: ThemeAccent? = nil) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.description = description
        self.philosophy = philosophy
        self.inspiration = inspiration
        self.collections = collections
        self.tags = tags
        self.look = look
        self.layout = layout
        self.research = research
        self.added = added
        self.baseline = baseline
        self.seasons = seasons
        self.version = version
        self.accent = accent
    }

    /// The light the set casts in the Themes hero. The one chosen for it
    /// (`accent`); otherwise its look's own accent; otherwise the color of
    /// its wallpaper, when the caller has measured one; otherwise warm gold.
    /// At each step a color with nothing to it (white on a black-and-white
    /// theme) is passed over, so such a theme ends on gold, not gray.
    public func lighting(wallpaper: WidgetColor? = nil) -> ThemeAccent {
        if let accent { return accent }
        let own = [setup?.accent, setup?.wallpaperAccent, designTheme?.palette(dark: isDark).accent]
            .compactMap { $0 }
            .filter(\.hasColor)
        guard let first = own.first ?? wallpaper.flatMap({ $0.hasColor ? $0 : nil }) else { return .neutral }
        let primary = first.lit
        // A second color of the look's own, when it has a different one;
        // otherwise the first again, paled, as haze.
        let other = own.dropFirst().first { $0.hueDistance(to: first) > 0.06 }
        return ThemeAccent(primary: primary, secondary: other?.lit ?? primary.paled, glowIntensity: isDark ? 0.9 : 0.65)
    }

    public var designTheme: DesignTheme? {
        if case .design(let id) = look { return DesignTheme.named(id) }
        return nil
    }

    public var setup: WidgetTheme? {
        if case .setup(let id) = look { return WidgetTheme.named(id) }
        return nil
    }

    public var wallpaper: WallpaperSource? { designTheme?.wallpaper ?? setup?.wallpaper }
    public var motion: MotionLanguage { designTheme?.motion ?? .calm }

    /// Whether it lives on a dark wallpaper.
    public var isDark: Bool {
        if let designTheme { return designTheme.dark != nil && (designTheme.light == nil || wallpaperIsDark) }
        return setup?.isDark ?? true
    }

    private var wallpaperIsDark: Bool {
        switch wallpaper {
        case .art(let piece): !piece.palette.isLight
        case .photo, .video, .library: true
        case nil: true
        }
    }

    /// The widgets it installs, laid out on a screen whose visible area is
    /// `bounds`, from the top left.
    public func widgets(screenName: String?, bounds: CGSize, now: Date = .now) -> [WidgetInstance] {
        if let setup { return setup.kitWidgets(screenName: screenName, bounds: bounds) }
        let step = WidgetSize.small.dimensions.width + WidgetLayout.spacing
        return layout.compactMap { item in
            guard var widget = WidgetCatalog.entry(item.entry)?.make(size: item.size) else { return nil }
            widget.screenName = screenName
            widget.offset = CGPoint(x: WidgetLayout.margin + Double(item.column) * step, y: WidgetLayout.margin + Double(item.row) * step)
            if let designTheme, !widget.kind.paintsOwnBackground, !widget.kind.isFreeform {
                widget.options.designTheme = designTheme.id
                widget.options.accent = nil
            }
            item.configure(&widget, now)
            widget.offset = WidgetLayout.snap(widget.offset, size: widget.footprint, within: bounds)
            return widget
        }
    }

    /// The widgets it includes, by gallery title, for the detail page.
    public var includedWidgets: [(title: String, symbol: String, size: WidgetSize)] {
        if let setup { return setup.kit.map { ($0.kind.title, $0.kind.symbol, $0.size) } }
        return layout.compactMap { item in
            WidgetCatalog.entry(item.entry).map { ($0.title, $0.symbol, item.size) }
        }
    }

    /// Everything search looks through.
    public var searchText: String {
        "\(name) \(tagline) \(inspiration ?? "") \(tags) \(collections.map(\.title).joined(separator: " ")) \(isDark ? "dark night" : "light bright") \(designTheme?.title ?? "")"
    }
}

/// One widget in a set's layout: a gallery entry, its size, its cell on a
/// grid of small-widget squares, and any content it starts with.
public struct SetItem: Sendable {
    public let entry: String
    public let size: WidgetSize
    public let column: Int
    public let row: Int
    public let configure: @Sendable (inout WidgetInstance, Date) -> Void

    public init(_ entry: String, _ size: WidgetSize, _ column: Int, _ row: Int,
                _ configure: @escaping @Sendable (inout WidgetInstance, Date) -> Void = { _, _ in }) {
        self.entry = entry
        self.size = size
        self.column = column
        self.row = row
        self.configure = configure
    }
}

/// The shelves and filters of the Themes library.
public enum ThemeCollection: String, CaseIterable, Identifiable, Sendable {
    case featured, artistWorlds, night, dreamy, retro, pop, indie, rock, hipHop, rnb, cinematic, cosmic, minimal
    case luxury, neon, ambient, zen, designer, developer, colourAndLight
    case football, musicIcons

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .featured: "Featured"
        case .artistWorlds: "Moodboards"
        case .night: "Night"
        case .dreamy: "Dreamy"
        case .retro: "Retro"
        case .pop: "Pop"
        case .indie: "Indie"
        case .rock: "Rock"
        case .hipHop: "Hip-Hop"
        case .rnb: "R&B"
        case .cinematic: "Cinematic"
        case .cosmic: "Cosmic"
        case .minimal: "Minimal"
        case .luxury: "Luxury"
        case .neon: "Neon"
        case .ambient: "Ambient"
        case .zen: "Japanese Zen"
        case .designer: "Designer"
        case .developer: "Developer"
        case .colourAndLight: "Colour & Light"
        case .football: "Football"
        case .musicIcons: "Music Icons"
        }
    }
}

/// Where a theme's look comes from, and what's original about it. Kept with
/// the theme, never shown as branding.
public struct ThemeResearch: Sendable {
    public struct Source: Sendable {
        public let title: String
        public let url: String

        public init(_ title: String, _ url: String) {
            self.title = title
            self.url = url
        }
    }

    public let artistInspiration: [String]
    public let visualEra: String
    public let primary: [Source]
    public let secondary: [Source]
    public let color: String
    public let typography: String
    public let motion: String
    public let texture: String
    public let photography: String
    /// What the theme draws on.
    public let referenced: String
    /// What's the theme's own.
    public let original: String
}

extension ThemeSet {
    /// A set's widgets with the given photos in every picture slot, in
    /// layout order and round again when there are more slots than photos:
    /// photos, tapes, prints, player portraits and lock screens. Player cards
    /// take the first photos, so put the best portrait first.
    public static func personalized(_ widgets: [WidgetInstance], with photos: [ImageSource]) -> [WidgetInstance] {
        guard !photos.isEmpty else { return widgets }
        var next = 0
        func take() -> ImageSource {
            defer { next += 1 }
            return photos[next % photos.count]
        }
        // Player cards first: the first photo is the portrait.
        var widgets = widgets
        for index in widgets.indices where widgets[index].kind == .playerCard {
            widgets[index].options.images = [take()]
        }
        return widgets.map { widget in
            var widget = widget
            switch widget.kind {
            case .photo, .vhs:
                widget.options.images = [take()]
            case .polaroids:
                widget.options.images = (0..<min(max(photos.count, 1), 6)).map { _ in take() }
            case .lockScreen:
                widget.options.background = take()
            default:
                break
            }
            return widget
        }
    }
}
