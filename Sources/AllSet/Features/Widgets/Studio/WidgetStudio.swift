import AllSetCore
import AppKit
import SwiftUI

/// A soft, colorful backdrop so glass widgets have something to show through.
struct StudioBackdrop: View {
    var piece = ArtPiece(style: .blobs, palette: .midnight)

    var body: some View {
        ArtView(piece: piece)
            .overlay(Color.black.opacity(0.1))
    }
}

// MARK: Gallery

struct GalleryCard: View {
    let entry: CatalogEntry
    let services: AppServices

    /// Every card is this tall: an exact frame keeps the grid from building cards to measure them.
    static let height: CGFloat = 372

    @State private var size: WidgetSize
    @State private var added = false
    /// Nil keeps the widget's own starting look.
    @State private var look: WidgetMaterial?
    /// A design theme picked on the card, for widgets drawn by themes.
    @State private var theme: String?
    /// Moves through the curated photos and palettes.
    @State private var variation = 0
    @State private var isHovering = false

    init(entry: CatalogEntry, services: AppServices) {
        self.entry = entry
        self.services = services
        _size = State(initialValue: entry.defaultSize)
    }

    private var kind: WidgetKind { entry.kind }
    private var entryIndex: Int { WidgetCatalog.entries.firstIndex { $0.id == entry.id } ?? 0 }
    /// Whether it starts out drawn by a design theme.
    private var isThemed: Bool { entry.make().options.designTheme != nil }

    /// Looks worth offering: kinds that paint their own backgrounds have none.
    private var looks: [WidgetMaterial] {
        switch kind {
        case .note, .photo, .ambient, .vinyl, .moon, .daylight, .polaroids, .sticker, .jersey, .playerCard, .pitch,
             .scoreboard, .cassette, .vhs, .visualizer, .ticket, .wordArt,
             .spiral, .charm, .label, .aura, .tarot, .zodiac, .eightBall, .candle: []
        case .neon: [.clear, .outline, .dark]
        default: [.photo, .paper, .frosted, .outline, .mesh, .glass, .art, .clear, .tinted, .dark]
        }
    }

    private static let themeChoices = ["native", "liquidGlass", "darkGlass", "aurora", "neumorphism", "editorial", "terminal", "brutalist"]

    private var sample: WidgetInstance {
        var instance = entry.make(size: size)
        if isThemed {
            if let theme { instance.options.designTheme = theme }
            return instance
        }
        let material = look ?? instance.material
        instance.material = material
        let palettes: [ArtPalette] = [.midnight, .aurora, .sunset, .lavender, .ocean, .neon, .peach, .forest]
        switch material {
        case .photo:
            if look != nil || variation > 0 {
                instance.options.background = .web(CuratedBackgrounds.suggestion(entryIndex * 11 + variation * 7))
            }
        case .mesh, .art:
            if look != nil || variation > 0 {
                instance.options.art = ArtPiece(style: material == .art ? ArtStyle.allCases[(entryIndex + variation) % ArtStyle.allCases.count] : .aurora,
                                                palette: palettes[(entryIndex + variation) % palettes.count])
            }
        case .tinted:
            instance.tint = WidgetColor.presets[(entryIndex + variation) % WidgetColor.presets.count]
        case .paper, .frosted:
            // A theme that uses this card, for colors that belong together.
            let themes = WidgetTheme.all.filter { $0.material == material }
            if look != nil || variation > 0, !themes.isEmpty {
                instance = themes[(entryIndex + variation) % themes.count].styled(instance)
                instance.material = material
            }
        case .clear where kind == .neon:
            let glows = [0xFF3CAC, 0x2DE2E6, 0xFFD23F, 0x9B5CFF, 0xFF3D3D]
            instance.tint = WidgetColor(hex: glows[(entryIndex + variation) % glows.count])
        case .clear:
            // The gallery's backdrops are dark.
            instance.tint = WidgetColor(red: 1, green: 1, blue: 1)
            instance.options.ink = WidgetColor(red: 1, green: 1, blue: 1)
            instance.options.accent = WidgetColor(red: 1, green: 1, blue: 1)
        default:
            break
        }
        return instance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ZStack {
                StudioBackdrop(piece: ArtPiece(style: .blobs, palette: backdropPalette))
                    .environment(\.widgetSnapshot, true).environment(\.widgetIsVisible, false)
                LibraryWidgetPreview(instance: sample, services: services, fit: CGSize(width: 250, height: 190), live: isHovering)
                    // Moving widgets come alive under the pointer; a page of
                    // them all moving at once would keep the Mac busy.
                    .environment(\.widgetIsVisible, isHovering)
                    .scaleEffect(isHovering ? 1.03 : 1)
                    .id("\(look?.rawValue ?? "default")-\(theme ?? "")-\(variation)-\(size.rawValue)")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Surface.hairline))
            .overlay(alignment: .topTrailing) {
                if !isThemed, !looks.isEmpty || kind == .photo {
                    Button {
                        withMotion(Motion.responsive) { variation += 1 }
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(FloatingButtonStyle(diameter: 30))
                    .padding(DS.Space.s)
                    .opacity(isHovering ? 1 : 0)
                    .help("Another photo or colors")
                    .accessibilityLabel("Show another look")
                }
            }
            .onHover { hovering in withMotion(Motion.responsive) { isHovering = hovering } }
            // Drag the preview out onto the desktop: the grid shows where it can go.
            .onDrag {
                services.ui.widgetDrop = sample
                return NSItemProvider(object: "All Set widget: \(entry.title)" as NSString)
            }
            .help("Drag onto the desktop, or use Add to Desktop")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of \(entry.title)")

            HStack(alignment: .top, spacing: DS.Space.s) {
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Label(entry.title, systemImage: entry.symbol).dsText(.headline)
                    Text(entry.summary).dsText(.meta).lineLimit(2)
                }
                Spacer(minLength: 0)
                if entry.sizes.count > 1 {
                    sizePicker
                }
            }

            if isThemed {
                chips(Self.themeChoices.compactMap(DesignTheme.named).map { ($0.id, $0.title) },
                      selected: theme ?? sample.options.designTheme) { id in theme = id }
            } else if !looks.isEmpty {
                chips(looks.map { ($0.rawValue, $0.title) }, selected: (look ?? entry.make().material).rawValue) { raw in
                    look = WidgetMaterial(rawValue: raw)
                }
            }

            Spacer(minLength: 0)

            Button {
                services.addWidget(sample)
                withMotion(Motion.responsive) { added = true }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withMotion(Motion.standard) { added = false }
                }
            } label: {
                Label(added ? "Added" : "Add to Desktop", systemImage: added ? "checkmark" : "plus")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pillProminent)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(DS.Space.s)
        .background(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous).fill(DS.Surface.raised))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous).strokeBorder(DS.Surface.hairline))
    }

    /// S, M, L in one capsule. A system segmented control took 10 ms to build, half a card.
    private var sizePicker: some View {
        HStack(spacing: 2) {
            ForEach(entry.sizes) { option in
                let isSelected = option == size
                Button {
                    withMotion(Motion.responsive) { size = option }
                } label: {
                    Text(option.shortTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.88) : DS.Ink.secondary)
                        .frame(minWidth: 22, minHeight: 20)
                        .background(Capsule().fill(isSelected ? Color.white.opacity(0.92) : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(DS.Surface.hover))
        .help("Size")
    }

    private func chips(_ items: [(String, String)], selected: String?, pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.xxs + 2) {
                ForEach(items, id: \.0) { id, title in
                    let isSelected = selected == id
                    Button {
                        withMotion(Motion.responsive) { pick(id) }
                    } label: {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.88) : DS.Ink.secondary)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(Capsule().fill(isSelected ? Color.white.opacity(0.92) : DS.Surface.hover))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    /// A different backdrop per entry keeps the gallery lively.
    private var backdropPalette: ArtPalette {
        let palettes: [ArtPalette] = [.midnight, .ocean, .lavender, .forest, .neon, .sunset, .aurora]
        return palettes[entryIndex % palettes.count]
    }
}

// MARK: Inspector

struct WidgetInspector: View {
    let id: UUID
    let services: AppServices
    @State private var words: [String] = []

    var body: some View {
        if let instance = services.widgets.instance(id) {
            HStack(spacing: 0) {
                ZStack {
                    StudioBackdrop()
                    VStack(spacing: DS.Space.m) {
                        WidgetPreview(instance: instance, services: services, fit: CGSize(width: 360, height: 360))
                            .motion(Motion.responsive, value: instance.size)
                            .onPreferenceChange(WidgetWordsKey.self) { found in
                                if found != words { words = found }
                            }
                        Text("Live preview").dsText(.eyebrow, color: .white.opacity(0.7))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous).strokeBorder(DS.Surface.hairline))
                .overlay(alignment: .topLeading) {
                    Button {
                        services.ui.page = .desktop
                    } label: {
                        Label("On Your Desktop", systemImage: "chevron.left")
                    }
                    .buttonStyle(.pill)
                    .padding(DS.Space.s)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withMotion(Motion.quick) { services.removeWidget(id) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.floating)
                    .padding(DS.Space.s)
                    .help("Remove from the desktop")
                    .accessibilityLabel("Remove \(instance.kind.title) from the desktop")
                }
                .frame(width: 400)
                .frame(maxHeight: .infinity)
                .padding([.leading, .bottom], DS.Space.l)

                Form {
                    WidgetOptionsEditor(id: id, services: services, words: words)
                }
                .dsFormStyle()
            }
        } else {
            EmptyState(symbol: "square.dashed", title: "Widget removed",
                       message: "Pick another widget, or add one from the gallery.",
                       actionTitle: "On Your Desktop", action: { services.ui.page = .desktop })
        }
    }
}

// MARK: On your desktop

/// Every widget on the desktop now, to customize or remove (with Undo).
struct DesktopWidgetsPage: View {
    let services: AppServices

    var body: some View {
        let widgets = services.widgets.widgets
        PageScaffold {
            PageHeader(eyebrow: widgets.count == 1 ? "1 widget" : "\(widgets.count) widgets", title: "On Your Desktop",
                       subtitle: "Click one to customize it. Removing is instant, and Undo brings it back.") {
                HStack(spacing: DS.Space.xs) {
                    Button {
                        services.ui.isArrangingWidgets.toggle()
                    } label: {
                        Label(services.ui.isArrangingWidgets ? "Done Arranging" : "Arrange", systemImage: "hand.draw")
                    }
                    .buttonStyle(.pill)
                    .disabled(widgets.isEmpty)
                    Button {
                        services.ui.page = .widgetAppearance
                    } label: {
                        Label("Look & Layout", systemImage: "paintbrush")
                    }
                    .buttonStyle(.pill)
                    .help("How every widget looks and lines up, all at once")
                    Button {
                        services.ui.page = .gallery(nil)
                    } label: {
                        Label("Add Widgets", systemImage: "plus")
                    }
                    .buttonStyle(.pillProminent)
                }
            }
            if widgets.isEmpty {
                EmptyState(symbol: "rectangle.dashed", title: "No widgets yet",
                           message: "Pick a theme for a whole desktop at once, or add widgets one by one.",
                           actionTitle: "Browse Themes", action: { services.ui.page = .themes })
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: DS.Space.l)], spacing: DS.Space.l) {
                    ForEach(Array(widgets.enumerated()), id: \.element.id) { index, instance in
                        DesktopWidgetCard(instance: instance, index: index, services: services)
                    }
                }
            }
        }
    }
}

private struct DesktopWidgetCard: View {
    let instance: WidgetInstance
    let index: Int
    let services: AppServices

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Button {
                services.ui.page = .widget(instance.id)
            } label: {
                ZStack {
                    StudioBackdrop(piece: ArtPiece(style: .blobs, palette: Self.palettes[index % Self.palettes.count]))
                    WidgetPreview(instance: instance, services: services, fit: CGSize(width: 200, height: 140))
                        // Still until pointed at, like the gallery.
                        .environment(\.widgetIsVisible, isHovering)
                        .allowsHitTesting(false)
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Surface.hairline))
                .scaleEffect(isHovering ? 1.02 : 1)
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in withMotion(Motion.responsive) { isHovering = hovering } }
            .accessibilityLabel("Customize \(instance.kind.title)")

            HStack(spacing: DS.Space.s) {
                Image(systemName: instance.kind.symbol).foregroundStyle(DS.Ink.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.kind.title).dsText(.headline).lineLimit(1)
                    Text(instance.size.title).dsText(.meta)
                }
                Spacer(minLength: 0)
                Button {
                    services.ui.page = .widget(instance.id)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(FloatingButtonStyle(diameter: 30))
                .help("Customize")
                .accessibilityLabel("Customize \(instance.kind.title)")
                Button {
                    withMotion(Motion.quick) { services.removeWidget(instance.id) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(FloatingButtonStyle(diameter: 30))
                .help("Remove from the desktop")
                .accessibilityLabel("Remove \(instance.kind.title) from the desktop")
            }
        }
    }

    private static let palettes: [ArtPalette] = [.midnight, .ocean, .lavender, .forest, .neon, .sunset, .aurora]
}
