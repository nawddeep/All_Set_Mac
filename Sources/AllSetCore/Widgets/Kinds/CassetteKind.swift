import Foundation

// `WidgetKind.cassette`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let cassette = WidgetKindDefinition(
        kind: .cassette, category: .music, title: "Cassette", symbol: "recordingtape",
        summary: "A mixtape whose reels turn while music plays",
        keywords: "cassette tape mixtape retro 90s 80s music reels",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0xFF5C8A)
            instance.options.customText = "summer mix"
        })
}
