import Foundation

// `WidgetKind.weather`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    // Designed for the extra-large size too.
    static let weather = WidgetKindDefinition(
        kind: .weather, category: .lifestyle, title: "Weather", symbol: "cloud.sun.fill",
        summary: "Conditions and forecast for a city",
        keywords: "forecast temperature rain sun",
        sizes: [.small, .medium, .large, .extraLarge], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .tinted
        })
}
