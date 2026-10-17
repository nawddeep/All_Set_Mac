import Foundation

// `WidgetKind.milestone`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let milestone = WidgetKindDefinition(
        kind: .milestone, category: .football, title: "Milestone", symbol: "trophy.fill",
        summary: "One big number worth celebrating",
        keywords: "goals record stat number achievement trophy count",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .frosted
            instance.tint = WidgetColor(hex: 0x0E0C0A)
            instance.options.ink = WidgetColor(hex: 0xF6F1E7)
            instance.options.accent = WidgetColor(hex: 0xE8C15A)
        })
}
