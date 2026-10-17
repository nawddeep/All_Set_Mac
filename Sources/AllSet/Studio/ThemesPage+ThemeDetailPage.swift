import AllSetCore
import AppKit
import SwiftUI

/// Everything about one theme: a live preview, what's in it, its colors,
/// type and motion, where it came from, and the ways to install it.
struct ThemeDetailPage: View {
    let setID: String
    let services: AppServices

    @AppStorage("themes.setsWallpaper") private var setsWallpaper = true
    @State private var confirmsReplace = false
    @State private var heroHovering = false
    @State private var done: String?
    @State private var heroWidgets: [WidgetInstance] = []

    var body: some View {
        if let set = ThemeLibrary.set(setID) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        Button {
                            services.ui.page = .themes
                        } label: {
                            Label("Themes", systemImage: "chevron.left")
                        }
                        .buttonStyle(.pill)
                        // Opening a theme: the desktop rises in, then its
                        // name, then what you can do with it.
                        hero(set).entrance(rise: 28)
                        titleRow(set).entrance(delay: 0.08)
                        actions(set).entrance(delay: 0.14)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: DS.Space.xl, alignment: .top)],
                                  alignment: .leading, spacing: DS.Space.xl) {
                            about(set)
                            included(set)
                            appearance(set)
                            palette(set)
                            typography(set)
                            // Only design skins carry a motion language; the
                            // setups would all read "Calm".
                            if set.designTheme != nil { motion(set) }
                        }
                        .entrance(delay: 0.2)
                        research(set)
                    }
                    .padding(.horizontal, DS.Space.pageMargin(for: geometry.size.width))
                    .padding(.vertical, DS.Space.xl)
                }
            }
            .background(AppBackground(accent: accent(of: set)))
            .task(id: services.themePhotos.version(of: set.id)) {
                heroWidgets = ThemeComposition.widgets(for: set, dark: set.isDark, services: services)
            }
            .confirmationDialog("Replace your widgets with \(set.name)?", isPresented: $confirmsReplace) {
                Button("Replace \(services.widgets.widgets.count) Widgets") { install(set, .replace, "Applied") }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Installs \(set.includedWidgets.count) widgets\(setsWallpaper && set.wallpaper != nil ? " and the wallpaper" : ""). You can undo it from the Themes page.")
            }
        } else {
            ContentUnavailableView("Theme not found", systemImage: "questionmark.square.dashed")
        }
    }

    /// Whether the set has pictures to swap for the person's own.
    private static func hasPhotoSlots(_ set: ThemeSet) -> Bool {
        set.widgets(screenName: nil, bounds: ThemeComposition.canvas).contains { [.photo, .vhs, .polaroids, .playerCard, .lockScreen].contains($0.kind) }
    }

    private func install(_ set: ThemeSet, _ mode: ThemeInstall, _ message: String) {
        withMotion(Motion.standard) {
            guard services.install(set, mode: mode, wallpaper: setsWallpaper) else { return }
            done = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withMotion(Motion.standard) { done = nil }
        }
    }

    private func hero(_ set: ThemeSet) -> some View {
        ThemeComposition(set: set, widgets: heroWidgets, services: services, dark: set.isDark, isLive: heroHovering)
            .aspectRatio(ThemeComposition.canvas.width / ThemeComposition.canvas.height, contentMode: .fit)
            .frame(maxWidth: 1080)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous).strokeBorder(DS.Surface.hairline))
            .dsElevated()
            .onHover { heroHovering = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of the \(set.name) desktop")
    }

    private func titleRow(_ set: ThemeSet) -> some View {
        let favorite = services.themeStats.isFavorite(set.id)
        return HStack(alignment: .top, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                if !set.collections.isEmpty {
                    Text(set.collections.prefix(4).map(\.title).joined(separator: "  ·  ")).dsText(.eyebrow)
                }
                Text(set.name).dsText(.hero)
                Text(set.inspiration ?? set.tagline).dsText(.body, color: DS.Ink.secondary)
            }
            Spacer()
            Button {
                withMotion(Motion.bouncy) { services.themeStats.toggleFavorite(set.id) }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .foregroundStyle(favorite ? Color.pink : DS.Ink.primary)
            }
            .buttonStyle(FloatingButtonStyle(diameter: 38))
            .help("Favorite")
            .accessibilityLabel(favorite ? "Remove from favorites" : "Add to favorites")
        }
    }

    /// The theme's own accent, for a faint glow at the top of the page.
    private func accent(of set: ThemeSet) -> Color? {
        if let theme = set.designTheme { return Color(theme.palette(dark: set.isDark).accent) }
        return set.setup.map { Color($0.wallpaperAccent) }
    }

    private func actions(_ set: ThemeSet) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            FlowLayout(spacing: DS.Space.xs) {
                Button {
                    confirmsReplace = true
                } label: {
                    Label(done ?? "Apply Theme", systemImage: done == nil ? "square.grid.3x3.topleft.filled" : "checkmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pillProminent)
                .keyboardShortcut(.defaultAction)
                .help("Replace your widgets with this set")
                Button {
                    services.previewOnDesktop(set, wallpaper: setsWallpaper)
                } label: {
                    Label("Preview on Desktop", systemImage: "eye")
                }
                .help("Try it on the desktop, then keep it or go back")
                .buttonStyle(.pill)
                Button {
                    install(set, .add, "Added")
                } label: {
                    Label("Add Widgets", systemImage: "plus.square.on.square")
                }
                .help("Add this set's widgets next to yours")
                .buttonStyle(.pill)
                Button {
                    install(set, .restyle, "Restyled")
                } label: {
                    Label("Restyle My Widgets", systemImage: "paintbrush")
                }
                .help("Keep your widgets, give them this look")
                .buttonStyle(.pill)
                Button {
                    services.install(set, mode: .replace, wallpaper: setsWallpaper)
                    services.ui.isArrangingWidgets = true
                } label: {
                    Label("Customize", systemImage: "slider.horizontal.3")
                }
                .help("Apply it, then arrange the widgets your way")
                .buttonStyle(.pill)
            }
            if Self.hasPhotoSlots(set) {
                FlowLayout(spacing: DS.Space.xs) {
                    Button {
                        Task {
                            guard await services.installWithMyPhotos(set, wallpaper: setsWallpaper) else { return }
                            withMotion(Motion.standard) { done = "Applied" }
                            try? await Task.sleep(for: .seconds(2.5))
                            withMotion(Motion.standard) { done = nil }
                        }
                    } label: {
                        Label("Use My Photos…", systemImage: "person.crop.rectangle.stack")
                    }
                    .help("Apply it with your own pictures in every photo, tape and print")
                    .buttonStyle(.pill)
                    if services.themePhotos.hasPhotos(set.id) {
                        Button {
                            withMotion(Motion.standard) { services.themePhotos.clear(set.id) }
                        } label: {
                            Label("Use Theme Photos", systemImage: "arrow.uturn.backward")
                        }
                        .help("Go back to the photos the theme comes with")
                        .buttonStyle(.pill)
                    }
                    Text(services.themePhotos.hasPhotos(set.id)
                         ? "Showing your \(services.themePhotos.photos[set.id]?.count ?? 0) photos. They're kept on this Mac only."
                         : set.collections.contains(.football) || set.collections.contains(.musicIcons)
                         ? "Add photos of your favorite player or artist: they fill every photo, tape and card."
                         : "Your pictures in every photo, tape and print.")
                        .dsText(.meta)
                }
            }
            Toggle("Change the wallpaper too", isOn: $setsWallpaper)
                .toggleStyle(.checkbox)
                .foregroundStyle(DS.Ink.secondary)
                .disabled(set.wallpaper == nil)
        }
    }

    /// One fact about the theme: a small label over its content, no box.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title).dsText(.eyebrow)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func about(_ set: ThemeSet) -> some View {
        section("About") {
            Text(set.description)
            Text(set.philosophy).foregroundStyle(.secondary)
        }
    }

    private func included(_ set: ThemeSet) -> some View {
        section("\(set.includedWidgets.count) Widgets") {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                ForEach(Array(set.includedWidgets.enumerated()), id: \.offset) { _, widget in
                    Label {
                        Text(widget.title) + Text("  \(widget.size.shortTitle)").foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: widget.symbol).foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func appearance(_ set: ThemeSet) -> some View {
        section(set.designTheme?.followsAppearance == true ? "Light & Dark" : "Appearance") {
            HStack(spacing: 10) {
                if set.designTheme?.followsAppearance == true {
                    labeled("Light") { ThemeSnapshot(set: set, dark: false, services: services) }
                    labeled("Dark") { ThemeSnapshot(set: set, dark: true, services: services) }
                } else {
                    labeled(set.isDark ? "Dark only" : "Light only") { ThemeSnapshot(set: set, dark: set.isDark, services: services) }
                }
            }
            if let theme = set.designTheme {
                Picker("Wallpaper color", selection: Binding(
                    get: { services.widgets.widgets.first { $0.options.designTheme == theme.id }?.options.accentMode
                            ?? (theme.accentSource == .wallpaper ? .automatic : .fixed) },
                    set: { mode in
                        for widget in services.widgets.widgets where widget.options.designTheme == theme.id {
                            services.widgets.update(widget.id) { $0.options.accentMode = mode }
                        }
                    }
                )) {
                    ForEach(WallpaperAdaptation.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Automatic tints highlights toward your wallpaper's color, never the whole widget. Applies to this theme's widgets on your desktop.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content().clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func palette(_ set: ThemeSet) -> some View {
        section("Colors") {
            let swatches = colors(set)
            HStack(spacing: 12) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(swatch.1))
                            .frame(width: 52, height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.12)))
                        Text(swatch.0).font(.caption2.weight(.semibold))
                        Text(swatch.1.hexString).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func colors(_ set: ThemeSet) -> [(String, WidgetColor)] {
        if let theme = set.designTheme {
            let palette = theme.palette(dark: set.isDark)
            var swatches = [("Card", palette.background)]
            if let second = palette.background2 { swatches.append(("Glow", second)) }
            swatches += [("Ink", palette.ink), ("Muted", palette.secondaryInk), ("Accent", palette.accent)]
            return swatches
        }
        if let setup = set.setup {
            return [("Card", setup.card), ("Ink", setup.ink), ("Accent", setup.accent), ("Wallpaper", setup.wallpaperAccent)]
        }
        return []
    }

    private func typography(_ set: ThemeSet) -> some View {
        let style = set.designTheme.map { theme in
            WidgetStyle.themed(theme, palette: theme.palette(dark: set.isDark), isDark: set.isDark, accent: Color(theme.palette(dark: set.isDark).accent))
        } ?? WidgetStyle.classic(font: set.setup?.font ?? .standard, accent: .accentColor, cornerRadius: 16)
        return section("Typography") {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text("12:47").font(style.number(44))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friday, 25 September").font(style.title(15))
                    Text("Up next").font(style.label(11)).textCase(style.uppercaseLabels ? .uppercase : nil).tracking(style.labelTracking)
                        .foregroundStyle(.secondary)
                    Text("All system fonts, in \(set.designTheme?.typography.font.title.lowercased() ?? "the setup's") style.")
                        .font(style.body(11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func motion(_ set: ThemeSet) -> some View {
        section("Motion: \(set.motion.title)") {
            MotionPreview(motion: set.motion, accent: set.designTheme.map { Color($0.palette(dark: set.isDark).accent) } ?? .accentColor)
            Text(set.motion.summary + " With Reduce Motion on, everything simply dissolves.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func research(_ set: ThemeSet) -> some View {
        if let research = set.research {
            DisclosureGroup("Design notes & references") {
                VStack(alignment: .leading, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                        note("Era", research.visualEra)
                        note("Color", research.color)
                        note("Type", research.typography)
                        note("Motion", research.motion)
                        note("Texture", research.texture)
                        note("Referenced", research.referenced)
                        note("Original", research.original)
                    }
                    Text("References").font(.subheadline.bold()).padding(.top, 4)
                    ForEach(Array((research.primary + research.secondary).enumerated()), id: \.offset) { _, source in
                        if let url = URL(string: source.url) {
                            Link(source.title, destination: url).font(.callout)
                        }
                    }
                    Text("An original theme inspired by public visual characteristics of a genre and era. Not affiliated with or endorsed by any artist; no logos, album art, photography or trademarks are used.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.quaternary.opacity(0.45)))
        }
    }

    private func note(_ title: String, _ text: String) -> some View {
        GridRow {
            Text(title).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).font(.callout)
        }
    }
}

/// A number changing and a dot arriving, the way the theme moves them.
struct MotionPreview: View {
    let motion: MotionLanguage
    let accent: Color

    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 18) {
            Text("\(42 + step % 3 * 7)%")
                .font(.system(size: 30, weight: .light).monospacedDigit())
                .contentTransition(motion == .still ? .identity : .numericText())
            ZStack(alignment: step.isMultiple(of: 2) ? .leading : .trailing) {
                Capsule().fill(.primary.opacity(0.08)).frame(width: 140, height: 8)
                Circle().fill(accent).frame(width: 16, height: 16)
            }
            .frame(width: 140)
        }
        .animation(motion.change, value: step)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                step += 1
            }
        }
        .accessibilityHidden(true)
    }
}

extension WidgetColor {
    /// "#1D1D1F"
    var hexString: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
