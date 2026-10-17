import Foundation

// `WidgetKind.system`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    // Designed for the extra-large size too.
    static let system = WidgetKindDefinition(
        kind: .system, category: .system, title: "System", symbol: "cpu",
        summary: "CPU, GPU, memory and top apps",
        keywords: "cpu gpu memory stats monitor",
        sizes: [.small, .medium, .large, .extraLarge], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
        })
}
