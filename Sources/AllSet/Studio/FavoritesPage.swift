import AllSetCore
import SwiftUI

/// The themes you hearted, and the ones you used lately.
struct FavoritesPage: View {
    let services: AppServices

    enum Tab: String, CaseIterable, Identifiable {
        case favorites = "Favorites", recent = "Recent"
        var id: String { rawValue }
        var symbol: String { self == .favorites ? "heart.fill" : "clock.fill" }
    }

    @State private var tab = Tab.favorites

    private var sets: [ThemeSet] {
        let stats = services.themeStats
        switch tab {
        case .favorites:
            return ThemeDiscovery.favorites.sets(stats: stats)
        case .recent:
            return ThemeLibrary.all
                .compactMap { set in stats.records[set.id]?.lastUsed.map { (set, $0) } }
                .sorted { $0.1 > $1.1 }
                .prefix(24).map(\.0)
        }
    }

    var body: some View {
        let sets = self.sets
        PageScaffold {
            PageHeader(eyebrow: "Yours", title: "Favorites", subtitle: "Themes you hearted and the ones you used lately.")
            HStack(spacing: DS.Space.xs) {
                ForEach(Tab.allCases) { item in
                    FilterPill(title: item.rawValue, symbol: item.symbol, isSelected: tab == item) {
                        withMotion(Motion.quick) { tab = item }
                    }
                }
            }
            if sets.isEmpty {
                EmptyState(symbol: tab.symbol,
                           title: tab == .favorites ? "No favorites yet" : "Nothing used yet",
                           message: tab == .favorites ? "Tap the heart on any theme to keep it here." : "Themes you install or try show up here.",
                           actionTitle: "Browse Themes", action: { services.ui.page = .themes })
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Space.m)], spacing: DS.Space.l) {
                    ForEach(sets) { set in ThemeSetCard(set: set, services: services) }
                }
            }
        }
    }
}
