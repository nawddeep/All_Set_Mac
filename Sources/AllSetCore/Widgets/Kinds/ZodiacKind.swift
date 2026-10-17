import Foundation

// `WidgetKind.zodiac`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let zodiac = WidgetKindDefinition(
        kind: .zodiac, category: .mystic, title: "Star Sign", symbol: "sparkles",
        summary: "Your sign's stars, twinkling",
        keywords: "zodiac star sign horoscope astrology constellation stars birthday",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x070A1A)
            instance.options.accent = WidgetColor(hex: 0xCFE3FF)
            instance.options.zodiac = ZodiacSign.sign(on: .now)
        })
}
