import Foundation

// `WidgetKind.pitch`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let pitch = WidgetKindDefinition(
        kind: .pitch, category: .football, title: "Tactics Board", symbol: "sportscourt.fill",
        summary: "A live tactics board with the ball in play",
        keywords: "football soccer pitch field tactics formation ball live",
        sizes: [.medium, .large, .extraLarge], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
