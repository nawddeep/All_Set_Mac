import Foundation

// `WidgetKind.enso`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let enso = WidgetKindDefinition(
        kind: .enso, category: .aesthetic, title: "Ensō", symbol: "circle.dashed",
        summary: "A brush circle that closes as the day ends",
        keywords: "zen enso circle japanese minimal day",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
            instance.options.designTheme = DesignTheme.zen.id
        })
}
