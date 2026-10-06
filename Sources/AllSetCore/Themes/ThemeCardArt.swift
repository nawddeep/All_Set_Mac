import CoreGraphics

/// What a theme's card in the Themes carousel shows: the theme's wallpaper
/// edge to edge, and a few of its own widgets floating over the upper part,
/// one of them large in the middle. The lower part stays wallpaper, for the
/// name and buttons laid over it.
///
/// The widgets are chosen from the theme's layout automatically (`picks`),
/// or by hand for themes that have been looked at (`curated`).
public enum ThemeCardArt {
    /// The space pieces are placed in: three small widgets wide and four
    /// tall with the desktop's gaps, so each widget is laid out at its real
    /// size and the whole is scaled to the card. 3:4, as the cards are.
    public static let canvas = CGSize(width: 552, height: 736)

    /// One widget on the card.
    public struct Piece: Equatable, Sendable {
        /// Which of the theme's widgets, by its place in the layout.
        public let widget: Int
        /// Its top-left corner on the canvas.
        public let origin: CGPoint
        /// How much smaller or larger than its own size it's drawn.
        public let scale: CGFloat
    }

    /// Which of a theme's widgets its card uses, by their place in its layout.
    public struct Picks: Equatable, Sendable {
        /// The large one in the middle.
        public var hero: Int
        /// A word across the top: the theme's name in script, a neon line.
        public var title: Int?
        /// Small ones beside the hero: upper left, lower right, upper
        /// right, lower left.
        public var flankers: [Int]
        /// How much larger than the card the wallpaper is drawn, to crop it
        /// to its best part; 1 shows all of it.
        public var zoom: CGFloat
        /// The point of the wallpaper that stays put when it's zoomed, in
        /// unit coordinates: (0.5, 0) keeps its top edge and crops the bottom.
        public var focus: CGPoint

        public init(hero: Int, title: Int? = nil, flankers: [Int] = [], zoom: CGFloat = 1, focus: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
            self.hero = hero
            self.title = title
            self.flankers = flankers
            self.zoom = zoom
            self.focus = focus
        }
    }

    /// Cards chosen by hand, by theme set id. Every other theme gets `picks`.
    public static let curated: [String: Picks] = [
        // The shirt under its gold script, with the gold card and the flip
        // clock, in front of the floodlit stands. The wallpaper is cropped
        // from the top until its pitch is out of the card: the pitch's
        // centre circle sat behind the name like a stray ring, and the
        // crop leaves the theme its two colors, red and gold.
        "setup.seven": Picks(hero: 0, title: 1, flankers: [4, 2, 10, 3], zoom: 1.64, focus: CGPoint(x: 0.5, y: 0)),
        // The VHS palms under the neon line, with roses, a heart and a headlight.
        "setup.americana": Picks(hero: 0, title: 1, flankers: [3, 9, 2, 8]),
        // The portrait under the bare clock, with the script word, the crown and the tiger.
        "setup.leopardNoir": Picks(hero: 2, title: 0, flankers: [5, 11, 10, 1]),
    ]

    /// The widgets a card shows when nobody has chosen them: the theme's
    /// word art across the top, its first large widget in the middle, and
    /// small ones of different kinds beside it.
    public static func picks(from widgets: [(kind: WidgetKind, size: WidgetSize)]) -> Picks? {
        guard !widgets.isEmpty else { return nil }
        let title = widgets.firstIndex { $0.kind == .wordArt }
        let rest = widgets.indices.filter { $0 != title }
        // A theme is designed around its first large widget; without one,
        // its first medium, then whatever it has.
        guard let hero = rest.first(where: { widgets[$0].size == .large })
            ?? rest.first(where: { widgets[$0].size == .medium })
            ?? rest.first ?? title else { return nil }
        // One small widget of each kind before a second of any, so the card
        // shows the theme's range rather than four photos.
        let smalls = rest.filter { $0 != hero && widgets[$0].size == .small }
        var flankers: [Int] = [], kinds = Set<WidgetKind>()
        for index in smalls where kinds.insert(widgets[index].kind).inserted { flankers.append(index) }
        for index in smalls where !flankers.contains(index) { flankers.append(index) }
        return Picks(hero: hero, title: title == hero ? nil : title, flankers: Array(flankers.prefix(4)))
    }

    /// Where each chosen widget goes on the canvas, back to front. Picks
    /// that point past the end of `sizes` are left out.
    public static func pieces(_ picks: Picks, sizes: [WidgetSize]) -> [Piece] {
        func size(_ widget: Int) -> CGSize? { sizes.indices.contains(widget) ? sizes[widget].dimensions : nil }
        let titleSize = picks.title.flatMap(size)
        // The hero's box: smaller and lower when a word sits above it.
        let side: CGFloat = titleSize == nil ? 370 : 342
        let box = CGRect(x: (canvas.width - side) / 2, y: titleSize == nil ? 104 : 180, width: side, height: side)

        var pieces: [Piece] = []
        // Flankers fill what's left beside the hero, a gap from it and from
        // the card's edge: whole, since a covered edge hides what they say.
        let gap: CGFloat = 8
        let flank = (canvas.width - side) / 2 - gap - 4
        let left = box.minX - gap - flank, right = box.maxX + gap
        let upper = box.minY + 24, lower = box.maxY - flank - 24
        // The left pair floats a little higher than the right.
        let slots = [CGPoint(x: left, y: upper - 10), CGPoint(x: right, y: lower + 10),
                     CGPoint(x: right, y: upper + 10), CGPoint(x: left, y: lower - 10)]
        for (slot, widget) in zip(slots, picks.flankers) {
            guard let size = size(widget) else { continue }
            let scale = flank / max(size.width, size.height)
            pieces.append(Piece(widget: widget,
                                origin: CGPoint(x: slot.x + (flank - size.width * scale) / 2,
                                                y: slot.y + (flank - size.height * scale) / 2),
                                scale: scale))
        }
        if let size = size(picks.hero) {
            let scale = min(box.width / size.width, box.height / size.height)
            pieces.append(Piece(widget: picks.hero,
                                origin: CGPoint(x: box.midX - size.width * scale / 2, y: box.midY - size.height * scale / 2),
                                scale: scale))
        }
        if let title = picks.title, let size = titleSize {
            let scale = min(300 / size.width, 150 / size.height)
            pieces.append(Piece(widget: title,
                                origin: CGPoint(x: (canvas.width - size.width * scale) / 2, y: 22 + (150 - size.height * scale) / 2),
                                scale: scale))
        }
        return pieces
    }
}
