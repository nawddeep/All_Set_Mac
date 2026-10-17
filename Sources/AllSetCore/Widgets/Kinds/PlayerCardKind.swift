import Foundation

// `WidgetKind.playerCard`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let playerCard = WidgetKindDefinition(
        kind: .playerCard, category: .football, title: "Player Card", symbol: "person.crop.rectangle.fill",
        summary: "A foil rating card with your photo and stats",
        keywords: "football soccer player card rating stats legend",
        sizes: [.small, .medium, .large], defaultSize: .large,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
