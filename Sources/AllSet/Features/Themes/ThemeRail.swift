import AllSetCore
import SwiftUI

/// Responsive shelves of cached desktops with arrow and trackpad navigation.
struct ThemeRail: View {
    let title: String
    let sets: [ThemeSet]
    let services: AppServices
    var availableWidth: CGFloat = 1200
    var viewportHeight: CGFloat = 800
    @State private var previewsVisible = false
    @State private var activation: Task<Void, Never>?
    var seeAll: (@MainActor () -> Void)?
    @State private var visibleID: String?

    private var cardWidth: CGFloat {
        let columns: CGFloat = availableWidth >= 1200 ? 5 : availableWidth >= 900 ? 4 : 3
        return max(190, (availableWidth - (columns - 1) * DS.Space.s) / columns)
    }

    var body: some View {
        if !sets.isEmpty {
            ScrollViewReader { scroller in
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    HStack(spacing: DS.Space.s) {
                        Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(title == "Recommended themes" ? Color.pink : Color.white.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(DS.Surface.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).dsText(.section)
                            Text(subtitle).dsText(.meta)
                        }
                        Spacer()
                        arrow("chevron.left", by: -1, scroller: scroller)
                        arrow("chevron.right", by: 1, scroller: scroller)
                        if let seeAll { Button("See all", action: seeAll).buttonStyle(.pill).controlSize(.small) }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: DS.Space.s) {
                            ForEach(sets) { set in
                                RailCard(set: set, services: services, requestsPreview: previewsVisible).frame(width: cardWidth).id(set.id)
                            }
                        }
                        .scrollTargetLayout().padding(.vertical, DS.Space.xxs)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $visibleID, anchor: .leading)
                    // A stable shelf height prevents lazy vertical layout from
                    // changing the scroll offset as horizontal cards appear.
                    .frame(height: cardWidth / ThemePreviewVariant.desktop.aspect + DS.Space.xxs * 2)
                }
                .background {
                    if !previewsVisible {
                        Color.clear.onGeometryChange(for: Bool.self) { proxy in
                            let frame = proxy.frame(in: .named("themesViewport"))
                            return frame.maxY > -160 && frame.minY < viewportHeight + 160
                        } action: { visible in
                            // Activate once, then remove the geometry observer:
                            // scrolling back must not rebuild or reload every card.
                            if visible, activation == nil {
                                activation = Task {
                                    guard await services.themePreviews.waitUntilScrollSettles() else { return }
                                    previewsVisible = true
                                }
                            } else if !visible {
                                activation?.cancel()
                                activation = nil
                            }
                        }
                    }
                }
                .onDisappear {
                    activation?.cancel()
                    activation = nil
                }
            }
        }
    }

    private var symbol: String {
        switch title {
        case "Recommended themes": "flame.fill"
        case "Football": "soccerball"
        case "Music Icons": "music.note"
        case "Night": "moon.stars.fill"
        case "Colour & Light": "sparkles"
        case "Developer": "chevron.left.forwardslash.chevron.right"
        default: "square.stack.3d.up"
        }
    }

    private var subtitle: String {
        switch title {
        case "Recommended themes": "Picked for the season and for what you use."
        case "Football": "For the beautiful game."
        case "Music Icons": "Set the mood. Find your rhythm."
        case "Colour & Light": "A brighter way to make it yours."
        default: "\(sets.count) complete desktop experiences."
        }
    }

    private func arrow(_ symbol: String, by direction: Int, scroller: ScrollViewProxy) -> some View {
        let current = sets.firstIndex { $0.id == visibleID } ?? 0
        let target = min(max(current + direction, 0), max(sets.count - 1, 0))
        return Button {
            withAnimation(ThemesMotion(services.ui.performance).snap) {
                scroller.scrollTo(sets[target].id, anchor: .leading)
                visibleID = sets[target].id
            }
        } label: { Image(systemName: symbol) }
        .buttonStyle(FloatingButtonStyle(diameter: 28)).disabled(target == current)
        .help(direction < 0 ? "Previous themes" : "Next themes")
        .accessibilityLabel(direction < 0 ? "Previous \(title)" : "Next \(title)")
    }
}

struct RailCard: View {
    let set: ThemeSet
    let services: AppServices
    var requestsPreview = true
    @State private var isHovering = false

    var body: some View {
        let favorite = services.themeStats.isFavorite(set.id)
        let active = services.settings.activeThemeSet == set.id
        let motion = ThemesMotion(services.ui.performance)
        let shape = RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        Button { services.ui.page = .themeSet(set.id) } label: {
            ThemeSnapshot(set: set, dark: set.isDark, services: services, requestsPreview: requestsPreview)
                .overlay(alignment: .bottomLeading) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(set.name).dsText(.headline).lineLimit(1)
                            Text("\(set.includedWidgets.count) widgets").dsText(.meta)
                        }.padding(DS.Space.s)
                    }.frame(height: 60)
                }
                .overlay(Color.white.opacity(isHovering ? 0.04 : 0))
                .clipShape(shape)
                .contentShape(shape)
                .overlay(shape.strokeBorder(active ? Color.cyan.opacity(0.8) : Color.white.opacity(isHovering ? 0.25 : 0.14),
                                            lineWidth: active ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button {
                withMotion(Motion.standard) { services.themeStats.toggleFavorite(set.id) }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .foregroundStyle(favorite ? Color.pink : DS.Ink.primary)
            }
            .buttonStyle(FloatingButtonStyle(diameter: 26)).padding(DS.Space.xs)
            .help(favorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityLabel(favorite ? "Remove \(set.name) from favorites" : "Favorite \(set.name)")
        }
        .scaleEffect(isHovering && motion.lifts ? 1.015 : 1)
        .onHover { value in withAnimation(motion.fade) { isHovering = value } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(set.name) theme, \(set.includedWidgets.count) widgets")
        .accessibilityHint("Opens theme details")
    }
}

/// Moodboard shortcuts show real category counts.
struct ThemeMoodboards: View {
    let services: AppServices
    @Binding var selection: String
    let availableWidth: CGFloat
    private let categories: [(ThemeDiscovery, String)] = [
        (.minimal, "softMono"), (.dark, "cityNoir"), (.colorful, "neonNights"),
        (.artist, "leopardNoir"), (.developer, "beginning"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "cube").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Ink.secondary).frame(width: 30, height: 30)
                    .background(DS.Surface.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Moodboards").dsText(.section)
                    Text("Curated theme collections for different vibes.").dsText(.meta)
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.s) {
                    ForEach(categories, id: \.0.id) { category, theme in
                        if let set = ThemeLibrary.set("setup.\(theme)") {
                            Button { selection = category.rawValue } label: {
                                ThemeSnapshot(set: set, dark: set.isDark, services: services, fills: true)
                                    .frame(width: max(180, (availableWidth - 48) / 5), height: 92)
                                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                                    .overlay(alignment: .bottomLeading) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(category.title).dsText(.headline)
                                            Text("\(category.sets(stats: services.themeStats).count) themes").dsText(.meta)
                                        }.padding(DS.Space.s)
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(DS.Ink.primary).padding(DS.Space.s)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.control))
                                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.control).strokeBorder(.white.opacity(0.14)))
                            }
                            .buttonStyle(.plain).accessibilityLabel("Browse \(category.title) themes")
                        }
                    }
                }.padding(.vertical, DS.Space.xxs)
            }
        }
    }
}
