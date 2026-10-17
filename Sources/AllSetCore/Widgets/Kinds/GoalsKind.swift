import Foundation

// `WidgetKind.goals`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let goals = WidgetKindDefinition(
        kind: .goals, category: .productivity, title: "Daily Goals", symbol: "target",
        summary: "A few counts to hit today",
        keywords: "goals water daily targets rings",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
