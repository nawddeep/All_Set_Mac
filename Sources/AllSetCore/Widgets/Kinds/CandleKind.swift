import Foundation

// `WidgetKind.candle`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let candle = WidgetKindDefinition(
        kind: .candle, category: .mystic, title: "Candle", symbol: "flame.fill",
        summary: "A candle flickering on your desktop",
        keywords: "candle flame fire cozy dark academia light calm flicker",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x110C08)
            instance.options.customText = "light a candle, make a wish"
        })
}
