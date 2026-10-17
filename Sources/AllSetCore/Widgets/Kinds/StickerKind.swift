import Foundation

// `WidgetKind.sticker`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let sticker = WidgetKindDefinition(
        kind: .sticker, category: .aesthetic, title: "Sticker", symbol: "heart.fill",
        summary: "A big star, heart or sparkle on the desktop",
        keywords: "star heart sparkle cute decoration emoji",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: true, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .clear
            instance.tint = WidgetColor(hex: 0xBFD4FF)
            instance.options.stickerTilt = -8
        })
}
