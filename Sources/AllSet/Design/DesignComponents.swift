import SwiftUI

// The shared building blocks of the main window. Pages compose these instead
// of styling their own boxes, headers and buttons.

// MARK: Canvas

/// A page's own touch on the window's backdrop (`WindowBackdrop`, drawn
/// once by the main window): its accent as a glow at the top, or nothing.
/// Never a fill, so the backdrop's light shows through every page.
struct AppBackground: View {
    var accent: Color?

    var body: some View {
        if let accent {
            RadialGradient(colors: [accent.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

// MARK: Page structure

/// A page's title block: an optional eyebrow, the title, a line of context,
/// and actions on the trailing edge.
struct PageHeader<Actions: View>: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                if let eyebrow { Text(eyebrow).dsText(.eyebrow) }
                Text(title).dsText(.title)
                if let subtitle {
                    Text(subtitle).dsText(.body, color: DS.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Space.m)
            actions
        }
    }
}

extension PageHeader where Actions == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A scrolling page on the canvas, with margins that follow the window's width.
struct PageScaffold<Content: View>: View {
    var accent: Color?
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Space.section) {
                    content
                }
                .padding(.horizontal, DS.Space.pageMargin(for: geometry.size.width))
                .padding(.vertical, DS.Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipped()
        }
        .background(AppBackground(accent: accent))
    }
}

/// A section's heading, with an optional "See All" on the trailing edge.
struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (@MainActor () -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title).dsText(.section)
                if let subtitle { Text(subtitle).dsText(.meta) }
            }
            Spacer(minLength: DS.Space.s)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(DS.TextRole.meta.font)
                    .foregroundStyle(DS.Ink.secondary)
            }
        }
    }
}

/// Facts in a row, separated by dots: "Space · 3840×2160 · 37 MB".
struct MetadataRow: View {
    let items: [String]

    var body: some View {
        Text(items.filter { !$0.isEmpty }.joined(separator: "  ·  "))
            .dsText(.meta)
            .lineLimit(1)
    }
}

// MARK: Media

/// Large media with its title and actions laid over a soft vignette: the top
/// of a content page. The media is the star; the text sits where it's darkest.
struct HeroSection<Media: View, Actions: View>: View {
    var eyebrow: String?
    let title: String
    var metadata: [String] = []
    var titleRole: DS.TextRole = .hero
    var height: CGFloat = 420
    /// Edge to edge and under the navigation, fading into the window's
    /// backdrop, instead of a rounded card.
    var bleed: BleedLayout?
    @ViewBuilder var media: Media
    @ViewBuilder var actions: Actions

    @Environment(UIState.self) private var ui: UIState?
    @State private var token = UUID()

    var body: some View {
        if let bleed {
            bleeding(bleed)
        } else {
            card
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            if let eyebrow { Text(eyebrow).dsText(.eyebrow, color: DS.Ink.secondary) }
            Text(title).dsText(titleRole).lineLimit(2).minimumScaleFactor(0.7)
            if !metadata.isEmpty { MetadataRow(items: metadata) }
            HStack(spacing: DS.Space.s) { actions }
                .padding(.top, DS.Space.xs)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func bleeding(_ layout: BleedLayout) -> some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Color.clear.overlay { media }.clipped()
                // The navigation floats over the top; the words sit bottom left.
                // Just enough for the navigation's words; more and its glass
                // has only darkness to show.
                LinearGradient(colors: [.black.opacity(0.32), .clear], startPoint: .top,
                               endPoint: .init(x: 0.5, y: min(layout.topInset * 1.8 / layout.height, 0.5)))
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .leading, endPoint: .center)
            }
            // Fades into the backdrop rather than onto a colour, so its light
            // runs on under the picture without a seam.
            .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                         .init(color: .black, location: 0.5),
                                         .init(color: .black.opacity(0.6), location: 0.75),
                                         .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            words
                .padding(.leading, layout.margin)
                .padding(.bottom, layout.overlap + DS.Space.xl)
        }
        .frame(height: layout.height)
        .frame(maxWidth: .infinity)
        // Tells the navigation whether the picture is still under it; only
        // flips twice per scroll past, never per frame.
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).maxY > layout.topInset + layout.overlap * 2
        } action: { under in
            if under {
                ui?.mediaUnderNavigation = token
            } else if ui?.mediaUnderNavigation == token {
                ui?.mediaUnderNavigation = nil
            }
        }
        .onDisappear {
            if ui?.mediaUnderNavigation == token { ui?.mediaUnderNavigation = nil }
        }
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            // The hero decides its size; media only fills it. Sized by the
            // media, a filling picture grew the stack and pushed the words out.
            Color.clear
                .overlay { media }
                .clipped()
            // Darkest bottom-left, where the words are; the rest of the media stays clear.
            LinearGradient(colors: [.black.opacity(0.78), .black.opacity(0.25), .clear],
                           startPoint: .bottom, endPoint: .center)
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .leading, endPoint: .center)
            words
                .padding(DS.Space.xl)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous).strokeBorder(DS.Surface.hairline))
    }
}

/// A rounded media card: artwork first, an optional title below or over it,
/// lifting a little under the pointer and ringed when chosen.
struct MediaCard<Media: View>: View {
    var aspectRatio: CGFloat = 16 / 9
    var isSelected = false
    var title: String?
    var subtitle: String?
    @ViewBuilder var media: Media

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay { media }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous)
                        .strokeBorder(isSelected ? DS.Ink.primary : DS.Surface.hairline, lineWidth: isSelected ? 2 : 1)
                }
                .scaleEffect(isHovering ? 1.02 : 1)
                .dsElevated()
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).dsText(.headline).lineLimit(1)
                    if let subtitle { Text(subtitle).dsText(.meta) }
                }
                .padding(.horizontal, DS.Space.xxs)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in withMotion(Motion.responsive) { isHovering = hovering } }
    }
}

/// A horizontal row of cards that scrolls and settles on a card's edge. Lazy:
/// only the cards in view are made.
struct MediaRail<Items: RandomAccessCollection, Card: View>: View where Items.Element: Identifiable {
    let items: Items
    var cardWidth: CGFloat = 260
    @ViewBuilder var card: (Items.Element) -> Card

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Space.m) {
                ForEach(items) { item in
                    card(item).frame(width: cardWidth)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, DS.Space.xs)
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

/// A large preview area: what a studio page is editing.
struct PreviewCanvas<Content: View>: View {
    var height: CGFloat = 360
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(DS.Surface.raised)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous).strokeBorder(DS.Surface.hairline))
    }
}

// MARK: Surfaces

/// Translucent glass for things that float over content: navigation,
/// overlays, sheets. Apple's Liquid Glass on macOS 26. Never for anything
/// that scrolls with the page: glass re-samples what's behind it every frame
/// it moves, which tripled scrolling CPU in the probe when every pill and
/// button was glass. Not for cards or lists either.
struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = DS.Radius.panel
    var padding: CGFloat = DS.Space.l
    /// How bright the lit rim is; under 1 for glass that sits second to
    /// another piece beside it.
    var rim: Double = 1
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let padded = content.padding(padding)
        // Regular glass over a dark picture in dark mode comes out as a near
        // solid dark capsule. The clear kind lets the picture through, and the
        // lit rim and faint sheen are what make it read as glass.
        if #available(macOS 26, *) {
            padded
                .glassEffect(.regular.tint(.white.opacity(0.05)), in: shape)
                .overlay(GlassRim(shape: shape).opacity(rim))
        } else {
            padded
                .background(.ultraThinMaterial, in: shape)
                .background(shape.fill(Color.white.opacity(0.04)))
                .overlay(GlassRim(shape: shape).opacity(rim))
        }
    }
}

/// Light catching a glass edge: bright at the top left, fading round the
/// sides, a softer catch at the bottom right, over a faint sheen on the
/// upper half. Static, so it costs nothing to draw.
private struct GlassRim<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        ZStack {
            shape.fill(LinearGradient(colors: [.white.opacity(0.07), .clear],
                                      startPoint: .top, endPoint: .center))
            shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.42), location: 0),
                                                      .init(color: .white.opacity(0.10), location: 0.35),
                                                      .init(color: .white.opacity(0.04), location: 0.65),
                                                      .init(color: .white.opacity(0.18), location: 1)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                               lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// The lit glass lens under the selected tab: Liquid Glass of its own, a touch
    /// brighter than the bar it sits in, that responds to the pointer.
    @ViewBuilder
    func glassLens() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(.white.opacity(0.24)).interactive(), in: Capsule())
        } else {
            background(Capsule().fill(.white.opacity(0.18)))
        }
    }
}

// MARK: Motion

extension View {
    /// Comes in when it first appears: rises a little and fades up, after
    /// `delay`. Opacity and offset only, so it's cheap; just a fade with
    /// Reduce Motion on.
    func entrance(delay: Double = 0, rise: CGFloat = 18) -> some View {
        modifier(Entrance(delay: delay, rise: rise))
    }
}

private struct Entrance: ViewModifier {
    let delay: Double
    let rise: CGFloat
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || Motion.reducesMotion ? 0 : rise)
            .scaleEffect(shown || Motion.reducesMotion ? 1 : 0.985, anchor: .top)
            .onAppear {
                guard !shown else { return }
                withAnimation(Motion.resolved(.spring(response: 0.5, dampingFraction: 0.86)).delay(delay)) { shown = true }
            }
    }
}

// MARK: Controls

/// Rounded pill buttons: `.pill` for most actions, `.pillProminent` for the
/// one primary action on a page.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, prominent: prominent)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(prominent ? Color.black.opacity(0.88) : DS.Ink.primary)
                .padding(.horizontal, DS.Space.m)
                .frame(height: 34)
                .background(Capsule().fill(fill))
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .contentShape(Capsule())
                .onHover { isHovering = $0 }
                .motion(Motion.press, value: configuration.isPressed)
        }

        private var fill: Color {
            if prominent { return .white.opacity(configuration.isPressed ? 0.8 : isHovering ? 1 : 0.92) }
            return configuration.isPressed ? DS.Surface.pressed : isHovering ? .white.opacity(0.13) : DS.Surface.hover
        }
    }
}

/// A round icon button that floats over content: favourite, close, arrows.
struct FloatingButtonStyle: ButtonStyle {
    var diameter: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DS.Ink.primary)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(.black.opacity(configuration.isPressed ? 0.6 : 0.42)))
            .overlay(Circle().strokeBorder(DS.Surface.hairline))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .contentShape(Circle())
            .motion(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var pillProminent: PillButtonStyle { PillButtonStyle(prominent: true) }
}

extension ButtonStyle where Self == FloatingButtonStyle {
    static var floating: FloatingButtonStyle { FloatingButtonStyle() }
}

/// A filter chip: a category, a kind, a sort.
struct FilterPill: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isSelected ? Color.black.opacity(0.88) : DS.Ink.secondary)
            .padding(.horizontal, DS.Space.s)
            .frame(height: 28)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.92) : DS.Surface.raised))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A rounded search field.
struct SearchField: View {
    @Binding var text: String
    var prompt = "Search"

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "magnifyingglass").foregroundStyle(DS.Ink.tertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(DS.Ink.primary)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Ink.tertiary) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, DS.Space.s)
        .frame(height: 34)
        .background(Capsule().fill(DS.Surface.raised))
        .overlay(Capsule().strokeBorder(DS.Surface.hairline))
    }
}

/// Nothing here yet: a symbol, a line, and what to do about it.
struct EmptyState: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (@MainActor () -> Void)?

    var body: some View {
        VStack(spacing: DS.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(DS.Ink.tertiary)
            Text(title).dsText(.headline)
            if let message {
                Text(message).dsText(.body, color: DS.Ink.secondary).multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.pill).padding(.top, DS.Space.xs)
            }
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xxl)
    }
}

// MARK: Layout

/// Lays views out in rows, wrapping to the next row when one is full: for
/// rows of pills and actions that must fit a narrow window.
struct FlowLayout: Layout {
    var spacing: CGFloat = DS.Space.s
    var lineSpacing: CGFloat = DS.Space.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Columns and card width for a grid of fixed-size cards in `width` points.
struct CardGridMetrics {
    let columns: Int
    let cardWidth: CGFloat
    let spacing: CGFloat

    init(width: CGFloat, minimumWidth: CGFloat, spacing: CGFloat) {
        columns = max(Int((width + spacing) / (minimumWidth + spacing)), 1)
        cardWidth = max(((width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down), 1)
        self.spacing = spacing
    }

    /// `items` cut into rows of `columns`.
    func chunks<Item>(_ items: [Item]) -> [[Item]] {
        stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }
}

/// Content below the fold, built a moment after the page appears instead of
/// in the same frame as the switch. The page shows at once (its hero and
/// first rows), and the rest arrives under `PageVeil`'s fade, which runs in
/// Core Animation and so keeps moving while the main thread builds it.
struct Deferred<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var isReady = false

    var body: some View {
        if isReady {
            content
        } else {
            Color.clear
                .frame(height: 1)
                .task { isReady = true }
        }
    }
}

/// A setting's switch: its name, with a line explaining it underneath.
/// VoiceOver reads the name as the setting and the explanation as a hint;
/// a two-line label alone was read out as the explanation, so "Keep
/// clipboard history" was announced as "Stored only on this Mac".
struct SettingToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    init(_ title: String, detail: String, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
            Text(detail)
        }
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}
