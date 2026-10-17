import Foundation

// `WidgetKind.daylight`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let daylight = WidgetKindDefinition(
        kind: .daylight, category: .lifestyle, title: "Daylight", symbol: "sun.horizon.fill",
        summary: "The sky right now, from sunrise to starlight",
        keywords: "sun sky sunrise sunset",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
