import Foundation

// `WidgetKind.tarot`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let tarot = WidgetKindDefinition(
        kind: .tarot, category: .mystic, title: "Tarot", symbol: "rectangle.portrait.on.rectangle.portrait.angled.fill",
        summary: "A card drawn for you each day",
        keywords: "tarot card daily reading fortune major arcana mystic witchy",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x0F0B16)
            instance.options.accent = WidgetColor(hex: 0xE8C15A)
        })
}
