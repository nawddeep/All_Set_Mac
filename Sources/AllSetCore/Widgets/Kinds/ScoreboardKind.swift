import Foundation

// `WidgetKind.scoreboard`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let scoreboard = WidgetKindDefinition(
        kind: .scoreboard, category: .football, title: "Scoreboard", symbol: "rectangle.split.2x1.fill",
        summary: "A stadium board counting down to kickoff",
        keywords: "football soccer match score kickoff countdown stadium game",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
