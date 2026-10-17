import Foundation

// `WidgetKind.dots`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let dots = WidgetKindDefinition(
        kind: .dots, category: .time, title: "Year in Dots", symbol: "circle.grid.3x3.fill",
        summary: "The year, or this month, as a grid of dots",
        keywords: "year progress days dots calendar minimal dark life",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .frosted
            instance.tint = WidgetColor(hex: 0x121216)
            instance.options.ink = WidgetColor(hex: 0xF2F2F2)
            instance.options.accent = WidgetColor(hex: 0xFFD23F)
        })
}
