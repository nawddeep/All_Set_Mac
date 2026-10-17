import Foundation

// `WidgetKind.aura`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let aura = WidgetKindDefinition(
        kind: .aura, category: .mystic, title: "Aura", symbol: "circle.hexagongrid.fill",
        summary: "Today's aura, glowing in its colors",
        keywords: "aura energy glow gradient mood colors orb spiritual vibe",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x0C0A12)
        })
}
