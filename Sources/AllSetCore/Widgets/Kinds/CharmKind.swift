import Foundation

// `WidgetKind.charm`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let charm = WidgetKindDefinition(
        kind: .charm, category: .aesthetic, title: "Charm", symbol: "heart.fill",
        summary: "A chrome charm that catches the light",
        keywords: "charm chrome heart star cross gothic wings angel butterfly moon bow y2k metal silver pendant",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: true, paintsOwnBackground: true,
        defaults: { instance in
            // Metal straight on the wallpaper.
            instance.material = .clear
            instance.tint = WidgetColor(hex: 0xDDE3F0)
        })
}
