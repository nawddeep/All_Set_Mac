import AllSetCore
import SwiftUI

/// The complete desktop in the spotlight; curated portraits on either side.
/// Apply and Preview sit beneath the carousel, leaving the imagery clear.
struct ThemePreviewCard: View {
    let set: ThemeSet
    let services: AppServices
    let isSelected: Bool
    var isCompact = false
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous) }

    var body: some View {
        let favorite = services.themeStats.isFavorite(set.id)
        let active = services.settings.activeThemeSet == set.id
        let light = services.lighting(of: set)
        let glow = Color(light.primary)
        ZStack(alignment: .bottomLeading) {
            Color.clear.overlay {
                ThemeSnapshot(set: set, dark: set.isDark, services: services, fills: true,
                              variant: isSelected ? .desktop : .card)
            }.clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.08), .black.opacity(0.82)],
                           startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 3) {
                Text(set.name).font(.system(size: isSelected ? 18 : 15, weight: .semibold))
                    .foregroundStyle(DS.Ink.primary).lineLimit(1)
                Text("\(set.includedWidgets.count) widgets").dsText(.meta)
            }
            .padding(DS.Space.s).padding(.trailing, 32)
        }
        .overlay(alignment: .topTrailing) {
            if isSelected || active {
                Text(active ? "On your desktop" : "Featured")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color(light.secondary).opacity(0.7)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
                    .padding(DS.Space.s)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                withMotion(Motion.standard) { services.themeStats.toggleFavorite(set.id) }
            } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .foregroundStyle(favorite ? Color.pink : DS.Ink.primary)
            }
            .buttonStyle(FloatingButtonStyle(diameter: 28)).padding(DS.Space.s)
            .help(favorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityLabel(favorite ? "Remove \(set.name) from favorites" : "Favorite \(set.name)")
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(LinearGradient(colors: [isSelected ? .cyan : glow.opacity(0.4),
                                                        isSelected ? Color(light.secondary) : glow.opacity(0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                               lineWidth: isSelected ? 1.5 : 1).allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(set.name) theme, \(set.includedWidgets.count) widgets")
    }
}
