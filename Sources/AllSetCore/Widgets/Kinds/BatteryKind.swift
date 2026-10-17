import Foundation

// `WidgetKind.battery`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let battery = WidgetKindDefinition(
        kind: .battery, category: .system, title: "Battery", symbol: "battery.100percent",
        summary: "Charge, health and power draw",
        keywords: "power charge",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
        })
}
