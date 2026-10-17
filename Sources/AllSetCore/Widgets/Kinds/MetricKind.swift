import Foundation

// `WidgetKind.metric`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let metric = WidgetKindDefinition(
        kind: .metric, category: .system, title: "System Metric", symbol: "gauge.with.dots.needle.33percent",
        summary: "One reading from your Mac, beautifully",
        keywords: "cpu memory ram disk storage network wifi battery health uptime status",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
