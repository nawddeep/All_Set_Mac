import Foundation

// `WidgetKind.airQuality`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let airQuality = WidgetKindDefinition(
        kind: .airQuality, category: .lifestyle, title: "Air Quality", symbol: "aqi.medium",
        summary: "The air outside, by US AQI",
        keywords: "air quality aqi pollution pm2.5 smog",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
