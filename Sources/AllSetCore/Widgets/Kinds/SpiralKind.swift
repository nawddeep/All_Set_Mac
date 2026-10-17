import Foundation

// `WidgetKind.spiral`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let spiral = WidgetKindDefinition(
        kind: .spiral, category: .aesthetic, title: "Spiral", symbol: "tornado",
        summary: "A hypnotic spiral that never stops turning",
        keywords: "spiral hypnotic hypnosis op art swirl vortex trippy black white illusion",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.tint = WidgetColor(hex: 0x0B0B0C)
            instance.options.ink = WidgetColor(hex: 0xF4F1EA)
        })
}
