import Foundation

// `WidgetKind.jersey`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let jersey = WidgetKindDefinition(
        kind: .jersey, category: .football, title: "Shirt", symbol: "tshirt.fill",
        summary: "Your name and number on a glowing shirt",
        keywords: "football soccer shirt kit jersey number name club team",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
