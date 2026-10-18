import AllSetCore
import AppKit
import SwiftUI

/// Ways to browse the library.
enum ThemeDiscovery: String, CaseIterable, Identifiable {
    case all, funkyThemes, datasetTwo, studioOriginals, desktopEdit, featured, trending, new, artist, football, music, popular, minimal, dark, colorful, developer, favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .funkyThemes: "Funky Themes"
        case .datasetTwo: "Monochrome Edit"
        case .studioOriginals: "Studio Originals"
        case .desktopEdit: "Desktop Edit"
        case .featured: "Featured"
        case .trending: "Recommended"
        case .new: "New"
        case .artist: "Moodboards"
        case .football: "Football"
        case .music: "Music Icons"
        case .popular: "Top Picks"
        case .minimal: "Minimal"
        case .dark: "Dark"
        case .colorful: "Colorful"
        case .developer: "Developer"
        case .favorites: "Favorites"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .funkyThemes: "sparkles.rectangle.stack"
        case .datasetTwo: "square.grid.3x3.topleft.filled"
        case .studioOriginals: "circle.hexagongrid"
        case .desktopEdit: "sparkles.rectangle.stack"
        case .featured: "star"
        case .trending: "chart.line.uptrend.xyaxis"
        case .new: "sparkle"
        case .artist: "photo.stack"
        case .football: "soccerball"
        case .music: "music.mic"
        case .popular: "flame"
        case .minimal: "circle"
        case .dark: "moon"
        case .colorful: "paintpalette"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .favorites: "heart"
        }
    }

    /// The sets it shows, in its own order.
    @MainActor
    func sets(stats: ThemeStats, now: Date = .now) -> [ThemeSet] {
        let all = ThemeLibrary.all
        switch self {
        case .all: return all
        case .funkyThemes: return ThemeLibrary.sets(in: .funkyThemes)
        case .datasetTwo: return ThemeLibrary.sets(in: .datasetTwo)
        case .studioOriginals: return ThemeLibrary.sets(in: .studioOriginals)
        case .desktopEdit: return ThemeLibrary.sets(in: .desktopEdit)
        case .featured: return all.filter { $0.collections.contains(.featured) }.sorted { stats.popularity($0) > stats.popularity($1) }
        case .trending: return all.sorted { stats.trending($0, now: now) > stats.trending($1, now: now) }.prefix(12).map { $0 }
        case .new:
            let recent = Calendar.current.date(byAdding: .day, value: -45, to: now) ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return all.filter { (formatter.date(from: $0.added) ?? .distantPast) >= recent }.sorted { $0.added > $1.added }
        case .artist: return all.filter { $0.collections.contains(.artistWorlds) }
        case .football: return all.filter { $0.collections.contains(.football) }
        case .music: return all.filter { $0.collections.contains(.musicIcons) }
        case .popular: return all.sorted { stats.popularity($0) > stats.popularity($1) }
        case .minimal: return all.filter { $0.collections.contains(.minimal) || $0.collections.contains(.zen) }
        case .dark: return all.filter(\.isDark)
        case .colorful: return all.filter(Self.isColorful)
        case .developer: return all.filter { $0.collections.contains(.developer) }
        case .favorites: return all.filter { stats.isFavorite($0.id) }
        }
    }

    /// A vivid accent, or a colorful wallpaper.
    private static func isColorful(_ set: ThemeSet) -> Bool {
        if set.collections.contains(.colourAndLight) { return true }
        if let theme = set.designTheme {
            let palette = theme.palette(dark: set.isDark)
            return palette.accent.hsvSaturation > 0.55 && !(theme.surface == .solid || theme.surface == .terminal)
        }
        if case .art(let piece) = set.wallpaper { return piece.palette.colors[2].hsvSaturation > 0.5 }
        return false
    }
}

// MARK: Library

/// The theme library: complete widget worlds to browse, preview and install.
struct ThemesPage: View {
    let services: AppServices

    @AppStorage("themes.setsWallpaper") private var setsWallpaper = true
    @AppStorage("themes.discovery") private var discovery = ThemeDiscovery.all.rawValue
    @State private var query = ""
    @State private var hero = ThemeHeroState()
    @State private var atmosphere = ThemeAtmosphereState()
    /// Marks the navigation's backdrop as this page's own while it shows.
    @State private var navigationToken = UUID()

    private var filter: ThemeDiscovery { ThemeDiscovery(rawValue: discovery) ?? .all }

    private var results: [ThemeSet] {
        let base = filter.sets(stats: services.themeStats)
        guard !SearchMatch.normalize(query).isEmpty else { return base }
        let allowed = Set(base.map(\.id))
        return ThemeLibrary.search(query).filter { allowed.contains($0.id) }
    }

    var body: some View {
        let sections = self.sections
        GeometryReader { geometry in
            let margin = DS.Space.pageMargin(for: geometry.size.width)
            let layout = BleedLayout(topInset: 0, visibleHeight: 0, margin: margin, viewport: geometry.size)
            let browsing = filter == .all && SearchMatch.normalize(query).isEmpty
            VStack(spacing: DS.Space.xs) {
                ThemesFilterBar(selection: $discovery, query: $query,
                                reduced: services.ui.performance.reducesMotion,
                                availableWidth: geometry.size.width - margin * 2)
                    .padding(.horizontal, margin)
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        if browsing {
                            ThemesHero(items: sections.featured, services: services, state: hero,
                                       atmosphere: atmosphere, layout: layout)
                        }
                        banners
                        if browsing {
                            ThemeRail(title: "Recommended themes", sets: ThemeDiscovery.trending.sets(stats: services.themeStats),
                                      services: services, availableWidth: geometry.size.width - margin * 2, viewportHeight: geometry.size.height)
                            ThemeMoodboards(services: services, selection: $discovery,
                                           availableWidth: geometry.size.width - margin * 2)
                            Deferred {
                                ForEach(sections.shelves, id: \.title) { rail in
                                    railView(rail, width: geometry.size.width - margin * 2, viewportHeight: geometry.size.height)
                                }
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(query.isEmpty ? filter.title : "Search results").dsText(.section)
                                    Text("\(results.count) themes").dsText(.meta)
                                }
                                Spacer()
                                Toggle("Include wallpaper", isOn: $setsWallpaper)
                                    .toggleStyle(.switch).controlSize(.small).dsText(.meta)
                            }
                            grid(results)
                        }
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, DS.Space.xs)
                    .padding(.bottom, DS.Space.xxl)
                    .background(LibraryScrollActivity(onBoundsChange: {
                        services.themePreviews.noteScrollMovement()
                    }))
                }
                .clipped()
                .coordinateSpace(name: "themesViewport")
                // A category/search change starts at its results, not a stale shelf offset.
                .id("\(filter.rawValue)#\(browsing)")
            }
            .background(alignment: .top) {
                ThemeAtmosphere(state: atmosphere, services: services,
                                focusY: ThemesHero.focusY(for: layout), panel: ThemesHero.carousel(for: layout).panelSize)
            }
        }
        .overlay(alignment: .top) { navigationBackdrop }
        // The navigation's backdrop is this page's (above), not the plain
        // canvas it paints for other pages.
        .onAppear {
            services.ui.mediaUnderNavigation = navigationToken
            #if DEBUG
            // `-heroTheme leopardNoir`: open the carousel on that theme, for pictures of it.
            if let name = UserDefaults.standard.string(forKey: "heroTheme"),
               let index = sections.featured.firstIndex(where: { $0.id == "setup.\(name)" }) {
                hero.index = index
            }
            #endif
        }
        .onDisappear {
            if services.ui.mediaUnderNavigation == navigationToken { services.ui.mediaUnderNavigation = nil }
        }
    }

    /// The top of the atmosphere again, cut to the navigation's height and
    /// held still under it. The page's own copy scrolls away with the
    /// content; this one stays, solid down to the navigation's lower edge
    /// and gone within the gap below it, so nothing that scrolls beneath
    /// the navigation shows through, and its backdrop is still the theme's
    /// light rather than plain canvas.
    private var navigationBackdrop: some View {
        GeometryReader { geometry in
            let inset = geometry.safeAreaInsets.top
            // The same numbers the hero is laid out with (`BleedScrollPage`).
            let layout = BleedLayout(topInset: inset, visibleHeight: 0, margin: DS.Space.pageMargin(for: geometry.size.width),
                                     viewport: geometry.size)
            ThemeAtmosphere(state: atmosphere, services: services, focusY: ThemesHero.focusY(for: layout),
                            panel: ThemesHero.carousel(for: layout).panelSize)
                .frame(height: inset, alignment: .top)
                .clipped()
                .mask {
                    VStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: DS.Space.s)  // the gap below the navigation
                    }
                }
                // Up into the navigation's own space, above where the page starts.
                .offset(y: -inset)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var banners: some View {
        DesktopUndoBanner(services: services)
    }

    private typealias Rail = (title: String, sets: [ThemeSet], more: ThemeDiscovery?)

    /// The carousel's themes, and the library below them as shelves: each
    /// shelf takes only what the ones above it haven't shown.
    private var sections: (featured: [ThemeSet], shelves: [Rail]) {
        let stats = services.themeStats
        var shown = Set<String>()
        func claim(_ sets: [ThemeSet]) -> [ThemeSet] {
            let fresh = sets.filter { !shown.contains($0.id) }
            shown.formUnion(fresh.map(\.id))
            return fresh
        }
        var shelves: [Rail] = [
            ("Funky Themes", claim(ThemeDiscovery.funkyThemes.sets(stats: stats)), .funkyThemes),
            ("Monochrome Edit", claim(ThemeDiscovery.datasetTwo.sets(stats: stats)), .datasetTwo),
            ("Studio Originals", claim(ThemeDiscovery.studioOriginals.sets(stats: stats)), .studioOriginals),
            ("Desktop Edit", claim(ThemeDiscovery.desktopEdit.sets(stats: stats)), .desktopEdit),
            ("Football", claim(ThemeDiscovery.football.sets(stats: stats)), .football),
            ("Music Icons", claim(ThemeDiscovery.music.sets(stats: stats)), .music),
            ("Colour & Light", claim(ThemeLibrary.sets(in: .colourAndLight)), nil),
            ("Moodboards", claim(ThemeDiscovery.artist.sets(stats: stats)), .artist),
            ("Night", claim(ThemeLibrary.sets(in: .night)), nil),
            ("Dreamy", claim(ThemeLibrary.sets(in: .dreamy)), nil),
            ("Minimal & Designer", claim(ThemeLibrary.sets(in: .designer) + ThemeLibrary.sets(in: .minimal)), nil),
            ("Developer", claim(ThemeDiscovery.developer.sets(stats: stats)), .developer),
        ]
        shelves.append(("More Setups", claim(ThemeLibrary.all), nil))
        let spotlight = ["haloAtlas", "tideglass", "verdantAfterdark", "duneStudy", "prismWorkshop", "ribbonRoom", "cobaltPaddock"]
            .compactMap { ThemeLibrary.set("setup.\($0)") }
        return (spotlight, shelves)
    }

    private func railView(_ rail: Rail, width: CGFloat, viewportHeight: CGFloat) -> some View {
        ThemeRail(title: rail.title, sets: rail.sets, services: services, availableWidth: width, viewportHeight: viewportHeight)
    }

    @ViewBuilder
    private func grid(_ sets: [ThemeSet]) -> some View {
        if sets.isEmpty {
            EmptyState(symbol: filter == .favorites ? "heart" : "magnifyingglass",
                       title: filter == .favorites ? "No favorites yet" : "No themes found",
                       message: filter == .favorites ? "Tap the heart on any theme to keep it here." : "Try another word or filter.")
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Space.m)], spacing: DS.Space.l) {
                ForEach(sets) { set in ThemeSetCard(set: set, services: services) }
            }
        }
    }
}

/// Offers to take back the last whole-desktop change: a theme going on, a new
/// wallpaper or a theme turned off. After it's gone, Widgets > Restore Previous
/// Desktop still can.
struct DesktopUndoBanner: View {
    let services: AppServices

    var body: some View {
        if let undo = services.ui.desktopUndo {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward.circle.fill").font(.title2).foregroundStyle(.tint)
                Text(message(for: undo.change))
                Spacer()
                Button("Undo") {
                    withMotion(Motion.standard) { services.undoDesktopChange() }
                }
                Button("Keep It") { withMotion(Motion.standard) { services.ui.desktopUndo = nil } }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.tint.opacity(0.12)))
            .task(id: undo.id) {
                // A new wallpaper is expected; the offer doesn't linger (the previous
                // desktop stays on disk for Restore Previous Desktop).
                guard undo.change == .wallpaper else { return }
                try? await Task.sleep(for: .seconds(12))
                if services.ui.desktopUndo?.id == undo.id {
                    withMotion(Motion.standard) { services.ui.desktopUndo = nil }
                }
            }
        }
    }

    private func message(for change: DesktopUndo.Change) -> String {
        switch change {
        case .theme(let name): "\(name) is on your desktop. Undo puts back your widgets, their look and your wallpaper."
        case .wallpaper: "New wallpaper. Your widgets are unchanged."
        case .turnedOff(let name): "\(name) is off. Undo brings back its widgets and look."
        case .link(let what): "\(what). Undo puts the desktop back as it was."
        }
    }
}

/// A theme set as a card: a miniature desktop of the whole set, its name
/// and what inspired it. Opens its detail page.
struct ThemeSetCard: View {
    let set: ThemeSet
    let services: AppServices

    @State private var isHovering = false
    @FocusState private var favoriteFocused: Bool

    var body: some View {
        let stats = services.themeStats
        let favorite = stats.isFavorite(set.id)
        Button {
            services.ui.page = .themeSet(set.id)
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                ThemeSnapshot(set: set, dark: set.isDark, services: services)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.media, style: .continuous).strokeBorder(DS.Surface.hairline))
                    .scaleEffect(isHovering ? 1.02 : 1)
                    .dsElevated()
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(set.name).dsText(.headline).lineLimit(1)
                        Spacer(minLength: DS.Space.xs)
                        Text("\(set.includedWidgets.count) widgets").dsText(.meta)
                    }
                    Text(set.inspiration ?? set.tagline)
                        .dsText(.meta)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.Space.xxs)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(set.name) theme, \(set.includedWidgets.count) widgets. \(set.tagline)")
        .accessibilityHint("Opens the theme")
        // A separate action over the card, never a Button inside a Button.
        .overlay(alignment: .topTrailing) {
            Button {
                withMotion(Motion.bouncy) { stats.toggleFavorite(set.id) }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .foregroundStyle(favorite ? Color.pink : DS.Ink.primary)
            }
            .buttonStyle(FloatingButtonStyle(diameter: 30))
            .padding(DS.Space.s)
            .opacity(isHovering || favorite || favoriteFocused ? 1 : 0)
            .allowsHitTesting(isHovering || favorite || favoriteFocused)
            .focused($favoriteFocused)
            .accessibilityLabel(favorite ? "Remove \(set.name) from favorites" : "Favorite \(set.name)")
        }
        .onHover { hovering in withMotion(Motion.responsive) { isHovering = hovering } }
    }
}

/// A theme's preview picture, drawn on first sight: its desktop, or its
/// portrait card for the carousel.
struct ThemeSnapshot: View {
    let set: ThemeSet
    let dark: Bool
    let services: AppServices
    /// Fills its frame (cropping) rather than keeping the picture's shape.
    var fills = false
    var variant = ThemePreviewVariant.desktop
    /// Offscreen shelves retain their size without decoding or drawing previews.
    var requestsPreview = true

    var body: some View {
        let cache = services.themePreviews
        ZStack {
            if requestsPreview, let image = cache.image(for: set, dark: dark, variant: variant) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).transition(.opacity)
            } else {
                Rectangle().fill(DS.Surface.raised)
                    .overlay { if requestsPreview { ProgressView().controlSize(.small) } }
            }
        }
        .aspectRatio(fills ? nil : variant.aspect, contentMode: fills ? .fill : .fit)
        .motion(Motion.standard, value: requestsPreview && cache.image(for: set, dark: dark, variant: variant) != nil)
        // Keyed on the purge generation too: a purge (memory pressure) drops
        // queued requests, and a card still waiting must ask again.
        .task(id: requestsPreview ? "\(cache.key(set, dark: dark, variant: variant))#\(cache.generation)" : "offscreen") {
            guard requestsPreview else { return }
            cache.request(set, dark: dark, variant: variant, services: services)
            defer { cache.cancel(set, dark: dark, variant: variant) }
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)) }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Detail
