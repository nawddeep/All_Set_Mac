import Foundation

// `WidgetKind.moon`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let moon = WidgetKindDefinition(
        kind: .moon, category: .lifestyle, title: "Moon", symbol: "moon.stars.fill",
        summary: "Tonight's moon and the phases ahead",
        keywords: "phases night lunar",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
