import AllSetCore
import SwiftUI

@MainActor @Observable
final class ThemeHeroState { var index = 0 }

/// Complete desktop, portrait neighbours, reflected light and stable actions.
struct ThemesHero: View {
    let items: [ThemeSet]
    let services: AppServices
    @Bindable var state: ThemeHeroState
    let atmosphere: ThemeAtmosphereState
    let layout: BleedLayout
    @AppStorage("themes.setsWallpaper") private var setsWallpaper = true

    static func carousel(for layout: BleedLayout) -> ThemeCarouselLayout {
        ThemeCarouselLayout(viewport: layout.viewport, margin: layout.margin, chrome: 128, footer: 104)
    }

    static func focusY(for layout: BleedLayout) -> CGFloat {
        layout.topInset + 48 + carousel(for: layout).cardSize.height / 2
    }

    var body: some View {
        if !items.isEmpty {
            let set = items[min(max(state.index, 0), items.count - 1)]
            let motion = ThemesMotion(services.ui.performance)
            let carousel = Self.carousel(for: layout)
            VStack(spacing: DS.Space.xs) {
                HeroCarousel(items: items, services: services, selection: $state.index, layout: carousel, margin: 0)
                    .frame(height: carousel.cardSize.height + DS.Space.l)
                    .background(alignment: .bottom) { floor(set, carousel: carousel, glows: motion.glows) }
                    .clipped()
                pagination(motion)
                VStack(spacing: 4) {
                    Text(set.name)
                        .font(.system(size: carousel.cardSize.height < 230 ? 22 : 26, weight: .bold))
                        .tracking(-0.5).foregroundStyle(DS.Ink.primary)
                    Text("\(set.includedWidgets.count) widgets" + (set.wallpaper == nil ? "" : " · Wallpaper included"))
                        .dsText(.meta)
                }
                .accessibilityElement(children: .combine)
                actions(set)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: carousel.panelSize.height, alignment: .top)
            .padding(.top, DS.Space.xs)
            .onChange(of: set.id, initial: true) { atmosphere.show(set, animation: motion.backdrop) }
            .task(id: items.map(\.id)) {
                for item in items { services.themePreviews.request(item, dark: item.isDark, variant: .backdrop, services: services) }
                defer { for item in items { services.themePreviews.cancel(item, dark: item.isDark, variant: .backdrop) } }
                while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)) }
            }
            .task(id: "\(set.id)#\(services.themePreviews.generation)") {
                await holdAdjacentPreviews()
            }
        }
    }

    private func holdAdjacentPreviews() async {
        // Prepare the adjacent desktops before they enter the spotlight.
        // Only two extras stay pinned; the normal cache still owns the rest.
        guard items.count > 1 else { return }
        let index = min(max(state.index, 0), items.count - 1)
        let indices = Set([(index + items.count - 1) % items.count, (index + 1) % items.count])
        let neighbours = indices.filter { $0 != index }.map { items[$0] }
        for item in neighbours { services.themePreviews.request(item, dark: item.isDark, services: services) }
        defer { for item in neighbours { services.themePreviews.cancel(item, dark: item.isDark) } }
        while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)) }
    }

    private func floor(_ set: ThemeSet, carousel: ThemeCarouselLayout, glows: Bool) -> some View {
        let lighting = services.lighting(of: set)
        return ZStack {
            EllipticalGradient(colors: [Color(lighting.primary).opacity(glows ? 0.27 : 0.08), .clear],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                .frame(width: carousel.cardSize.width * 1.7, height: 70)
            EllipticalGradient(colors: [Color(lighting.secondary).opacity(glows ? 0.3 : 0.06), .clear],
                               center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                .frame(width: carousel.cardSize.width, height: 52).offset(x: carousel.cardSize.width * 0.3)
            if let image = services.themePreviews.image(for: set, dark: set.isDark) {
                Image(nsImage: image).resizable()
                    .frame(width: carousel.cardSize.width, height: carousel.cardSize.height)
                    .scaleEffect(x: 1, y: -1)
                    .mask(LinearGradient(colors: [.black.opacity(0.16), .clear],
                                         startPoint: .top, endPoint: .init(x: 0.5, y: 0.18)))
                    .offset(y: carousel.cardSize.height / 2 + 12)
            }
        }
        .frame(height: 40).allowsHitTesting(false).accessibilityHidden(true)
    }

    private func pagination(_ motion: ThemesMotion) -> some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    withAnimation(motion.snap) { state.index = index }
                } label: {
                    Circle().fill(index == state.index ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 5, height: 5)
                        .frame(width: 17, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(items[index].name)
                .accessibilityLabel("Show \(items[index].name)")
                .accessibilityAddTraits(index == state.index ? .isSelected : [])
            }
        }
    }

    private func actions(_ set: ThemeSet) -> some View {
        let active = services.settings.activeThemeSet == set.id
        let favorite = services.themeStats.isFavorite(set.id)
        return HStack(spacing: DS.Space.xs) {
            Button {
                if active { services.turnOffTheme() }
                else { services.install(set, mode: .replace, wallpaper: setsWallpaper) }
            } label: {
                Label(active ? "Turn Off Theme" : "Apply Theme", systemImage: active ? "power" : "sparkles")
                    .padding(.horizontal, DS.Space.s)
            }
            .buttonStyle(.pillProminent)
            .help(active ? "Remove this theme from your desktop" : "Apply the wallpaper and coordinated widgets")
            Button { services.previewOnDesktop(set, wallpaper: setsWallpaper) } label: {
                Label("Preview on Desktop", systemImage: "display")
            }
            .buttonStyle(.pill).help("Try this theme, then keep it or restore your desktop")
            Button {
                withMotion(Motion.standard) { services.themeStats.toggleFavorite(set.id) }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .foregroundStyle(favorite ? Color.pink : DS.Ink.primary)
            }
            .buttonStyle(FloatingButtonStyle(diameter: 32))
            .help(favorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityLabel(favorite ? "Remove from favorites" : "Add to favorites")
            Menu {
                Toggle("Include wallpaper", isOn: $setsWallpaper)
                Button("View theme details") { services.ui.page = .themeSet(set.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(DS.Ink.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 24)
            .help("Theme options")
            .accessibilityLabel("Theme options")
        }
        .padding(.top, 4)
    }
}
